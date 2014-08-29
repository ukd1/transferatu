require "spec_helper"

describe Transferatu::Schedule do
  describe "#mark_executed" do
    it "flags the schedule as having been executed at the given time" do
      before = Time.now
      s = create(:schedule, hour: 15, dows: [ 3 ], timezone: 'UTC')
      s.mark_executed
      expect(s.last_scheduled_at).to be > before
    end
  end

  describe ".pending_for" do
    let(:scheduled_time) { Time.new(2014, 8, 20, 15, 0, 0, 0) } # this is a Wednesday, dow 3

    it "includes schedules for this day, time, and timezone" do
      s = create(:schedule, hour: 15, dows: [ 3 ], timezone: 'UTC')
      scheds = Transferatu::Schedule.pending_for(scheduled_time).all
      expect(scheds.count).to eq(1)
      expect(scheds.first.uuid).to eq(s.uuid)
    end

    it "includes schedules for this and other days, this time and timezone" do
      s = create(:schedule, hour: 15, dows: [ 1, 3, 5 ], timezone: 'UTC')
      scheds = Transferatu::Schedule.pending_for(scheduled_time).all
      expect(scheds.count).to eq(1)
      expect(scheds.first.uuid).to eq(s.uuid)
    end

    it "omits schedules for this day but another time in this timezone" do
      s = create(:schedule, hour: 14, dows: [ 3 ], timezone: 'UTC')
      scheds = Transferatu::Schedule.pending_for(scheduled_time).all
      expect(scheds).to be_empty
    end

    it "omits schedules for this day and time in another timezone" do
      s = create(:schedule, hour: 15, dows: [ 3 ], timezone: 'America/Los_Angeles')
      scheds = Transferatu::Schedule.pending_for(scheduled_time).all
      expect(scheds).to be_empty
    end

    it "omits schedules for a different day at this time in this timezone" do
      s = create(:schedule, hour: 15, dows: [ 4 ], timezone: 'UTC')
      scheds = Transferatu::Schedule.pending_for(scheduled_time).all
      expect(scheds).to be_empty
    end

    it "includes schedules for this day and an equivalent time in a different timezone" do
      s = create(:schedule, hour: 18, dows: [ 3 ], timezone: 'Africa/Addis_Ababa')
      scheds = Transferatu::Schedule.pending_for(scheduled_time).all
      expect(scheds.count).to eq(1)
      expect(scheds.first.uuid).to eq(s.uuid)
    end

    it "includes schedules for an equivalent day and time in a different timezone" do
      s = create(:schedule, hour: 1, dows: [ 4 ], timezone: 'Asia/Khandyga')
      scheds = Transferatu::Schedule.pending_for(scheduled_time).all
      expect(scheds.count).to eq(1)
      expect(scheds.first.uuid).to eq(s.uuid)
    end

    it "obeys an optional limit" do
      s1 = create(:schedule, hour: 15, dows: [ 3 ], timezone: 'UTC')
      s2 = create(:schedule, hour: 15, dows: [ 3 ], timezone: 'UTC')
      scheds = Transferatu::Schedule.pending_for(scheduled_time, limit: 1).all
      expect(scheds.count).to eq(1)
      expect(scheds.first.uuid).to satisfy { |v| [ s1.uuid, s2.uuid ].include? v }
    end

    it "omits schedules that have a recently-created transfer" do
      s = create(:schedule, hour: 15, dows: [ 3 ], timezone: 'UTC')
      create(:transfer, schedule: s)
      scheds = Transferatu::Schedule.pending_for(scheduled_time).all
      expect(scheds).to be_empty
    end

    it "omits deleted schedules" do
      s = create(:schedule, hour: 15, dows: [ 3 ], timezone: 'UTC')
      s.destroy
      scheds = Transferatu::Schedule.pending_for(scheduled_time).all
      expect(scheds).to be_empty
    end
  end
end

