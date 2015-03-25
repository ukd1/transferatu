require "spec_helper"

module Transferatu
  describe Mediators::Schedules::Updator do
    describe ".call" do
      let(:group)      { create(:group) }
      let(:schedule)   { create(:schedule, group: group) }
      let(:name)       { "Arthur" }
      let(:valid_tz)   { "America/New_York" }
      let(:bogus_tz)   { "America/Lodi" }
      let(:valid_hour) { 20 }
      let(:bogus_hour) { 26 }
      let(:valid_days) { %w(Monday Wednesday Friday) }
      let(:bogus_days) { %w(Caturday) }
      let(:valid_url)  { 'https://example.com/scheduled-transfers/123' }
      let(:bogus_url)  { 'ftp://example.com/scheduled-transfers/123' }

      it "updates an existing schedule" do
        updator = Mediators::Schedules::Updator.new(schedule: schedule,
                                                    name: name,
                                                    callback_url: valid_url,
                                                    hour: valid_hour,
                                                    days: valid_days,
                                                    timezone: valid_tz,
                                                    retain_weeks: 3,
                                                    retain_months: 6)
        t = updator.call
        expect(t).to_not be_nil
        expect(t).to be_instance_of(Transferatu::Schedule)
      end

      it "executes no-op updates" do
        updator = Mediators::Schedules::Updator
                  .new(schedule: schedule,
                       name: schedule.name,
                       callback_url: schedule.callback_url,
                       hour: schedule.hour,
                       days: schedule.dows.map { |d| Date::DAYNAMES[d] },
                       timezone: schedule.timezone,
                       retain_weeks: schedule.retain_weeks,
                       retain_months: schedule.retain_months)
        t = updator.call
        expect(t).to_not be_nil
        expect(t).to be_instance_of(Transferatu::Schedule)
      end

      it "fails with a bogus timezone" do
        expect {
          Mediators::Schedules::Updator.new(schedule: schedule,
                                            name: name,
                                            callback_url: valid_url,
                                            hour: valid_hour,
                                            days: valid_days,
                                            timezone: bogus_tz,
                                            retain_weeks: 3,
                                            retain_months: 6).call
        }.to raise_error
      end

      it "fails with a bogus hour" do
        expect {
          Mediators::Schedules::Updator.new(schedule: schedule,
                                            name: name,
                                            callback_url: valid_url,
                                            hour: bogus_hour,
                                            days: valid_days,
                                            timezone: valid_tz,
                                            retain_weeks: 3,
                                            retain_months: 6).call
        }.to raise_error
      end

      it "fails with a bogus set of days" do
        expect {
          Mediators::Schedules::Updator.new(group: group,
                                            name: name,
                                            callback_url: valid_url,
                                            hour: valid_hour,
                                            days: bogus_days,
                                            timezone: valid_tz,
                                            retain_weeks: 3,
                                            retain_months: 6).call
        }.to raise_error
      end

      it "fails with a bogus callback_url" do
        expect {
          Mediators::Schedules::Updator.new(group: group,
                                            name: name,
                                            callback_url: bogus_url,
                                            hour: valid_hour,
                                            days: valid_days,
                                            timezone: valid_tz,
                                            retain_weeks: 3,
                                            retain_months: 6).call
        }.to raise_error
      end
    end
  end
end
