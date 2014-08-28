require 'spec_helper'

module Transferatu
  describe Transferatu::ScheduleManager do
    let(:processor) { double(:resolver) }
    let(:manager)   { ScheduleManager.new(processor) }
    let(:time)      { Time.new(2014, 8, 28, 20, 0, 0, 0) }
    let(:sched1)    { double(:schedule1) }
    let(:sched2)    { double(:schedule2) }
    let(:batch1)    { double(:schedules, all: [ sched1, sched2 ]) }
    let(:batch2)    { double(:schedules, all: []) }

    describe "#run_schedules" do
      it "processes each schedule for a given time" do
        allow(Schedule).to receive(:pending_for)
          .with(time, limit: 250).and_return(batch1, batch2)
        [ sched1, sched2 ].each do |sched|
          expect(processor).to receive(:process).with(sched)
        end
        manager.run_schedules(time)
      end
    end
  end
end
