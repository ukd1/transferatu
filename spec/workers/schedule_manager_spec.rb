require 'spec_helper'

module Transferatu
  describe Transferatu::ScheduleManager do
    let(:processor) { double(:resolver) }
    let(:manager)   { ScheduleManager.new(processor) }
    let(:time)      { Time.new(2014, 8, 28, 20, 0, 0, 0) }
    let(:group)     { double(:group) }
    let(:sched1)    { double(:schedule1,
                             name: 'HEROKU_POSTGRESQL_MAUVE_URL',
                             uuid: 'cfdabdc2-c83e-4bc1-b0eb-f7633d8f683f',
                             group: group) }
    let(:sched2)    { double(:schedule2) }
    let(:batch1)    { double(:schedules, all: [ sched1, sched2 ]) }
    let(:batch2)    { double(:schedules, all: []) }

    describe "#run_schedules" do
      before do
        allow(Schedule).to receive(:pending_for)
          .with(time, limit: 250).and_return(batch1, batch2)
      end

      it "processes each schedule for a given time" do
        [ sched1, sched2 ].each do |sched|
          expect(processor).to receive(:process).with(sched)
        end
        manager.run_schedules(time)
      end

      it "retries a schedule once if it fails" do
        expect(processor).to receive(:process).with(sched1).and_raise(StandardError)
        expect(processor).to receive(:process).with(sched1)
        expect(processor).to receive(:process).with(sched2)
        manager.run_schedules(time)
      end

      it "marks a schedule as executed, logs to group, and reports to Rollbar if it fails twice" do
        expect(Rollbar).to receive(:error) do |e, opts|
          expect(e).to be_a StandardError
          expect(opts[:schedule_id]).to eq(sched1.uuid)
        end
        expect(group).to receive(:log) { |line| expect(line).to match /could not create/i }
        expect(sched1).to receive(:mark_executed)

        expect(processor).to receive(:process).with(sched1).and_raise(StandardError).twice
        expect(processor).not_to receive(:process).with(sched1)
        expect(processor).to receive(:process).with(sched2)
        manager.run_schedules(time)
      end
    end
  end
end
