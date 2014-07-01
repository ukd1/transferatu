require 'spec_helper'

module Transferatu
  describe Transferatu::TransferSupervisor do
    let(:worker)   { double(:worker) }
    let(:transfer) { double(:transfer) }
    describe ".run_next" do
      it "runs the next transfer when one is available" do
        Transfer.should_receive(:begin_next_pending).and_return(transfer)
        worker.should_receive(:perform).with(transfer)
        TransferSupervisor.run_next(worker)
      end
      it "sleeps when no transfers are available" do
        Transfer.should_receive(:begin_next_pending).and_return(nil)
        worker.should_not_receive(:perform)
        TransferSupervisor.should_receive(:sleep) do |naptime|
          expect(naptime).to be >= 1
          expect(naptime).to be <= 5
        end
        TransferSupervisor.run_next(worker)
      end
    end
  end
end
