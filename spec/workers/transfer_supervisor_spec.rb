require 'spec_helper'

module Transferatu
  describe Transferatu::TransferSupervisor do
    let(:worker)   { double(:worker) }
    let(:transfer) { double(:transfer) }

    describe ".run_next" do
      it "runs the next transfer when one is available" do
        expect(Transfer).to receive(:begin_next_pending).and_return(transfer)
        expect(worker).to receive(:perform).with(transfer)
        TransferSupervisor.run_next(worker)
      end

      it "asks the worker to wait if no transfers are available" do
        expect(Transfer).to receive(:begin_next_pending).and_return(nil)
        expect(worker).to receive(:wait)
        TransferSupervisor.run_next(worker)
      end
    end
  end
end
