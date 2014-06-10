require "spec_helper"

module Transferatu
  describe Transfer do
    describe ".begin_next_pending" do
      let(:time) { Time.now }
      let!(:t0)   { create(:transfer, created_at: time - 10) }
      let!(:t1)   { create(:transfer) }
      let!(:t2)   { create(:transfer, started_at: time - 1) }
      let!(:t3)   { create(:transfer, started_at: time - 30, finished_at: time - 5) }

      it "finds the oldest transfer" do
        expect(Transfer.begin_next_pending.uuid).to eq(t0.uuid)
      end
      it "begins the transfer it returns" do
        xfer = Transfer.begin_next_pending
        expect(xfer.started_at).to_not be_nil
      end
      it "returns nil when there are no pending transfers" do
        t0.update(started_at: Time.now)
        t1.update(started_at: Time.now)
        expect(Transfer.begin_next_pending).to be_nil
      end
    end
  end
end
