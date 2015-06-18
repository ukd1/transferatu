module Transferatu
  class ScheduleManager
    def initialize(processor)
      @processor = processor
    end

    def run_schedules(schedule_time)
      # limit the work to batches to avoid huge queries
      schedules = next_batch(schedule_time)
      until schedules.empty? do
        Parallel.each(schedules, in_threads: 4) do |s|
          process_schedule(s)
        end
        schedules = next_batch(schedule_time)
      end
    end

    private

    def process_schedule(s)
      retrying = false
      begin
        @processor.process(s)
      rescue StandardError => e
        if retrying
          Rollbar.error(e, schedule_id: s.uuid)
          s.group.log "Could not create scheduled transfer for #{s.name}"
          s.mark_executed
        else
          retrying = true
          retry
        end
      end
    end

    def next_batch(time)
      Schedule.pending_for(time, limit: 250).all
    end
  end
end
