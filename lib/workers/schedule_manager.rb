module Transferatu
  class ScheduleManager
    def initialize(processor)
      @processor = processor
    end

    def run_schedules(schedule_time)
      # limit the work to batches to avoid huge queries
      schedules = next_batch(schedule_time)
      until schedules.empty? do
        schedules.each do |s|
          @processor.process(s)
        end
        schedules = next_batch(schedule_time)
      end
    end

    private

    def next_batch(time)
      Schedule.pending_for(time, limit: 250).all
    end
  end
end
