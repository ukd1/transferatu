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
        # TODO: we should probably check that the naptime here is as
        # expected, but it's hard to do that with the existing rspec
        # hooks
        TransferSupervisor.stub(:sleep)
        TransferSupervisor.run_next(worker)        
      end
    end
  end
end
