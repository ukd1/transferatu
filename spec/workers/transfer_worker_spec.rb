require 'spec_helper'

module Transferatu
  describe Transferatu::TransferWorker do
    class DummyRunner
      def initialize(success, duration=0)
        @dur = duration
        @result = success
      end
      def processed_bytes
        tot = 1024**3
        [ (Time.now.to_f / (@start.to_f + @dur) * tot), tot ].min
      end
      def cancel; @result = false; end
      def run_transfer
        @start = Time.now
        sleep @dur
        @result
      end
    end

    SLOW_RUNTIME = 0.1

    let(:good_runner) { DummyRunner.new(true) }
    let(:bad_runner)  { DummyRunner.new(false) }
    let(:slow_runner) { DummyRunner.new(true, SLOW_RUNTIME) }
    let(:transfer)    { create(:transfer,
                               from_url: 'postgres:///test',
                               to_url: 's3://test') }
    let(:worker)      { Transferatu::TransferWorker.new }

    before do
      worker.stub(:sleep) { |time| sleep 0.05 }
    end

    it "should record success in case of a successful transfer" do
      RunnerFactory.should_receive(:runner_for).with(transfer).and_return(good_runner)
      worker.perform(transfer)
      transfer.reload
      expect(transfer.in_progress?).to be_false
      expect(transfer.failed?).to be_false
      expect(transfer.canceled?).to be_false
      expect(transfer.succeeded?).to be_true
    end

    it "should record failure in case of a failed transfer" do
      RunnerFactory.should_receive(:runner_for).with(transfer).and_return(bad_runner)
      worker.perform(transfer)
      transfer.reload
      expect(transfer.in_progress?).to be_false
      expect(transfer.failed?).to be_true
      expect(transfer.canceled?).to be_false
      expect(transfer.succeeded?).to be_false
    end

    it "should cancel the run when a transfer is canceled" do
      # N.B.: we get a new transfer fabricated if we reference the
      # same let from separate threads; avoid that with a local
      # variable
      xfer = transfer
      
      RunnerFactory.should_receive(:runner_for) { |t| t.uuid == xfer.uuid }.and_return(slow_runner)
      xfer_th = Thread.new { worker.perform(xfer) }
      xfer.cancel
      xfer_th.join

      xfer.reload
      expect(xfer.in_progress?).to be_false
      expect(xfer.failed?).to be_true
      expect(xfer.canceled?).to be_true
      expect(xfer.succeeded?).to be_false
    end

    it "should update progress in the course of a transfer" do
      # Same as above; avoid separate transfer objects
      xfer = transfer

      RunnerFactory.should_receive(:runner_for) { |t| t.uuid == xfer.uuid }.and_return(slow_runner)
      xfer_th = Thread.new { worker.perform(xfer) }
      sleep SLOW_RUNTIME / 4
      xfer.reload
      expect(xfer.in_progress?).to be_true
      expect(xfer.failed?).to be_false
      expect(xfer.canceled?).to be_false
      expect(xfer.succeeded?).to be_false
      expect(xfer.processed_bytes).to be > 0
      expect(xfer.processed_bytes).to be < 1024**3

      xfer_th.join
    end
  end
end
