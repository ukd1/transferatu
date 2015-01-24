require 'spec_helper'

module Transferatu
  describe Transferatu::TransferWorker do
    let(:status)      { create(:worker_status) }
    let(:worker)      { Transferatu::TransferWorker.new(status) }

    describe "#perform" do
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

      before do
        allow(worker).to receive(:sleep) { |time| sleep 0.05 }
      end

      it "should record success in case of a successful transfer" do
        expect(RunnerFactory).to receive(:runner_for).with(transfer).and_return(good_runner)
        worker.perform(transfer)
        transfer.reload
        expect(transfer.in_progress?).to be false
        expect(transfer.failed?).to be false
        expect(transfer.canceled?).to be false
        expect(transfer.succeeded?).to be true
      end

      it "should record failure in case of a failed transfer" do
        expect(RunnerFactory).to receive(:runner_for).with(transfer).and_return(bad_runner)
        worker.perform(transfer)
        transfer.reload
        expect(transfer.in_progress?).to be false
        expect(transfer.failed?).to be true
        expect(transfer.canceled?).to be false
        expect(transfer.succeeded?).to be false
      end

      it "should cancel the run when a transfer is canceled" do
        # N.B.: we get a new transfer fabricated if we reference the
        # same let from separate threads; avoid that with a local
        # variable
        xfer = transfer
        xfer.update(started_at: Time.now)

        expect(RunnerFactory).to receive(:runner_for) do |t|
          expect(t.uuid).to eq xfer.uuid
          slow_runner
        end
        xfer_th = Thread.new { worker.perform(xfer) }
        xfer.cancel
        xfer_th.join

        xfer.reload
        expect(xfer.in_progress?).to be false
        expect(xfer.failed?).to be true
        expect(xfer.canceled?).to be true
        expect(xfer.succeeded?).to be false
      end

      it "should update progress in the course of a transfer" do
        # Same as above; avoid separate transfer objects
        xfer = transfer
        xfer.update(started_at: Time.now)

        expect(RunnerFactory).to receive(:runner_for) do |t|
          expect(t.uuid).to eq xfer.uuid
          slow_runner
        end
        xfer_th = Thread.new { worker.perform(xfer) }
        sleep SLOW_RUNTIME / 4
        xfer.reload
        expect(xfer.in_progress?).to be true
        expect(xfer.failed?).to be false
        expect(xfer.canceled?).to be false
        expect(xfer.succeeded?).to be false
        expect(xfer.processed_bytes).to be > 0
        expect(xfer.processed_bytes).to be < 1024**3

        xfer_th.join
      end

      it "should update progress after a transfer" do
        # Same as above; avoid separate transfer objects
        xfer = transfer
        xfer.update(started_at: Time.now)

        expect(RunnerFactory).to receive(:runner_for) do |t|
          expect(t.uuid).to eq xfer.uuid
          slow_runner
        end
        xfer_th = Thread.new { worker.perform(xfer) }
        sleep SLOW_RUNTIME / 4
        xfer_th.join
        xfer.reload
        expect(xfer.in_progress?).to be false
        expect(xfer.failed?).to be false
        expect(xfer.canceled?).to be false
        expect(xfer.succeeded?).to be true
        expect(xfer.processed_bytes).to eq 1024**3
      end

      it "should update its status to reflect the transfer it is performing" do
        start = Time.now
        # See above
        xfer = transfer
        xfer.update(started_at: start)

        expect(RunnerFactory).to receive(:runner_for) do |t|
          expect(t.uuid).to eq xfer.uuid
          slow_runner
        end
        xfer_th = Thread.new { worker.perform(xfer) }
        sleep SLOW_RUNTIME / 4
        expect(status.updated_at).to be > start
        expect(status.transfer_id).to eq xfer.uuid

        xfer_th.join

        expect(status.transfer_id).to be nil
      end

      it "should clear its active transfer even if processing the transfer raises" do
        start = Time.now
        # See above
        xfer = transfer
        xfer.update(started_at: start)

        fake_runner = double(:runner)

        expect(RunnerFactory).to receive(:runner_for) do |t|
          expect(t.uuid).to eq xfer.uuid
          fake_runner
        end
        expect(fake_runner).to receive(:run_transfer) do
          sleep SLOW_RUNTIME
          raise StandardError
        end
        xfer_th = Thread.new { expect { worker.perform(xfer) }.to raise_error }
        sleep SLOW_RUNTIME / 4

        expect(status.updated_at).to be > start
        expect(status.transfer_id).to eq xfer.uuid

        xfer_th.join

        expect(status.transfer_id).to be nil
      end

      it "should fail the transfer and log an error if RunnerFactory raises a StandardError" do
        err_msg = 'oh snap!'
        expect(RunnerFactory).to receive(:runner_for) do |t|
          expect(t.uuid).to eq transfer.uuid
          raise StandardError, err_msg
        end
        expect(transfer.logs).to be_empty
        expect { worker.perform(transfer) }.to_not raise_error
        expect(transfer.failed?).to be true

        line = transfer.logs(limit: -1).find { |line| line.message =~ /could not initialize/i }
        expect(line).not_to be_nil
        expect(line.level).to eq('info')

        internal_line = transfer.logs(limit: -1).find { |line| line.message == err_msg }
        expect(internal_line).not_to be_nil
        expect(internal_line.level).to eq('internal')

        backtrace_line = transfer.logs(limit: -1).find { |line| line.message =~ /#{__FILE__}/ }
        expect(backtrace_line).not_to be_nil
        expect(backtrace_line.level).to eq('internal')
      end

      it "should fail the transfer and log a slightly more specific error if RunnerFactory raises a Sequel::DatabaseError" do
        err_msg = 'oh snap!'
        expect(RunnerFactory).to receive(:runner_for) do |t|
          expect(t.uuid).to eq transfer.uuid
          raise Sequel::DatabaseError, err_msg
        end
        expect(transfer.logs).to be_empty
        expect { worker.perform(transfer) }.to_not raise_error
        expect(transfer.failed?).to be true

        line = transfer.logs(limit: -1).find { |line| line.message =~ /could not connect to database/i }
        expect(line).not_to be_nil
        expect(line.level).to eq('info')

        internal_line = transfer.logs(limit: -1).find { |line| line.message == err_msg }
        expect(internal_line).not_to be_nil
        expect(internal_line.level).to eq('internal')

        backtrace_line = transfer.logs(limit: -1).find { |line| line.message =~ /#{__FILE__}/ }
        expect(backtrace_line).not_to be_nil
        expect(backtrace_line.level).to eq('internal')
      end
    end

    describe "#wait" do
      it "sleeps and updates its worker status" do
        start = Time.now
        expect(worker).to receive(:sleep) do |naptime|
          expect(naptime).to be >= 1
          expect(naptime).to be <= 5
        end
        worker.wait
        expect(status.updated_at).to be > start
      end
    end
  end
end
