require 'spec_helper'

module Transferatu
  describe Transferatu::ScheduleProcessor do
    let(:schedule)  { create(:schedule) }
    let(:resolver)  { double(:resolver) }
    let(:processor) { Transferatu::ScheduleProcessor.new(resolver) }
    let(:xfer_info) { {
                       "from_type" => 'pg_dump',
                       "from_url" => 'postgres:///test1',
                       "from_name" => 'george',
                       "to_type" => 'gof3r',
                       "to_url" => 'auto',
                       "to_name" => 'hortense',
                       "options" => {}
                      } }

    describe "#process" do
      context "with a transfer that resolves" do
        before do
          expect(resolver).to receive(:resolve).with(schedule).and_return(xfer_info)
        end

        it "creates transfers for the schedule" do
          expect(Transferatu::Mediators::Transfers::Creator).to receive(:run)
            .with(group: schedule.group, schedule: schedule,
                  from_type: xfer_info["from_type"],
                  from_url:  xfer_info["from_url"],
                  from_name: xfer_info["from_name"],
                  to_type:   xfer_info["to_type"],
                  to_url:    xfer_info["to_url"],
                  to_name:   xfer_info["to_name"],
                  options:   xfer_info["options"])
          processor.process(schedule)
        end

        it "runs the expirer" do
          before = Time.now
          expect(Transferatu::Mediators::Schedules::Expirer).to receive(:run) do |opts|
            expect(opts[:schedule]).to be schedule
            expect(opts[:expire_at]).to be > before
          end
          processor.process(schedule)
        end

        it "flags schedule as executed" do
          allow(Transferatu::Mediators::Transfers::Creator).to receive(:run)
          before = Time.now
          processor.process(schedule)
          expect(schedule.last_scheduled_at).to be > before
        end

        it "does not flag the schedule as executed if its transfer fails to be created" do
          expect(Transferatu::Mediators::Transfers::Creator).to receive(:run)
            .and_raise(StandardError)
          expect(Transferatu::Mediators::Schedules::Expirer).to_not receive(:run)
          processor.process(schedule)
          expect(schedule.last_scheduled_at).to be_nil
        end
      end

      it "logs the failure to the group for schedules that fail to resolve" do
        expect(resolver).to receive(:resolve).with(schedule).and_raise StandardError
        expect(Transferatu::Mediators::Transfers::Creator).to_not receive(:run)
        expect(Transferatu::Mediators::Schedules::Expirer).to_not receive(:run)
        expect(schedule.group).to receive(:log).with /could not create.*#{schedule.name}/i
        processor.process(schedule)
      end

      it "destroys schedules that resolve to nil" do
        expect(resolver).to receive(:resolve).with(schedule).and_return(nil)
        expect(schedule.group).to receive(:log).with /destroying.*#{schedule.name}/i
        processor.process(schedule)
        expect(schedule.deleted_at).to_not be_nil
      end
    end
  end
end
