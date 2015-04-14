require 'spec_helper'

module Transferatu
  describe Transferatu::TransferSupervisor do
    let(:worker)   { double(:worker) }
    let(:transfer) { create(:transfer) }

    describe ".run_next" do
      it "runs the next transfer when one is available" do
        expect(Transfer).to receive(:begin_next_pending).and_return(transfer)
        expect(worker).to receive(:perform).with(transfer)
        TransferSupervisor.run_next(worker)
      end

      it "traces a transfer when the 'trace' option is set" do
        expect(Transfer).to receive(:begin_next_pending).and_return(transfer)
        expect(worker).to receive(:perform).with(transfer)
        expect(Transferatu::ResourceUsage).to receive(:tracking)
          .with(transfer.uuid, transfer.from_type, transfer.to_type, 'ruby')
          .and_yield
        transfer.update(options: { 'trace' => true })
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
