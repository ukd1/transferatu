require "spec_helper"

module Transferatu
  describe Mediators::Schedules::Expirer do
    describe ".call" do
      let(:schedule)    { create(:schedule) }
      let(:expire_time) { Time.new(2001, 1, 1, 12, 0, 0, 0) }
      let(:expirer)     { Mediators::Schedules::Expirer.new(schedule, expire_time) }

      it "ignores everything newer than one week" do
        xfers = []
        (1..6).each do |n|
          xfers << create(:transfer, schedule: schedule, created_at: expire_time - n.days)
        end

        expirer.call

        xfers.each do |xfer|
          xfer.reload
          expect(xfer.deleted?).to be false
        end
      end

      it "keeps the only transfer older than one week but newer than two weeks" do
        xfer = create(:transfer, schedule: schedule, created_at: expire_time - 10.days)
        expirer.call
        xfer.reload
        expect(xfer.deleted?).to be false
      end

      it "keeps the oldest transfer older than one week but newer than two weeks" do
        xfer1 = create(:transfer, schedule: schedule, created_at: expire_time - 10.days)
        xfer2 = create(:transfer, schedule: schedule, created_at: expire_time - 11.days)
        expirer.call
        xfer1.reload; xfer2.reload
        expect(xfer1.deleted?).to be true
        expect(xfer2.deleted?).to be false
      end

      it "keeps the oldest transfer older than one week but newer than each of 2-5 weeks" do
        expected_deleted = []
        expected_kept = []
        (2..5).each do |n|
          expected_kept << create(:transfer, schedule: schedule,
                                  created_at: expire_time - n.weeks + 1.day)
          expected_deleted << create(:transfer, schedule: schedule,
                                     created_at: expire_time - n.weeks + 2.days)
        end
        expirer.call
        expected_deleted.each do |xfer|
          xfer.reload
          expect(xfer.deleted?).to be true
        end
        expected_kept.each do |xfer|
          xfer.reload
          expect(xfer.deleted?).to be false
        end
      end

      it "deletes everything older than 5 weeks" do
        xfer1 = create(:transfer, schedule: schedule, created_at: expire_time - 6.weeks)
        xfer2 = create(:transfer, schedule: schedule, created_at: expire_time - 7.weeks)
        expirer.call
        xfer1.reload; xfer2.reload
        expect(xfer1.deleted?).to be true
        expect(xfer2.deleted?).to be true
      end
    end
  end
end
