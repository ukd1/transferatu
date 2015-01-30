module Transferatu
  class ScheduleProcessor
    def initialize(resolver)
      @resolver = resolver
    end

    # Process a single schedule: resolve it to transfer data and
    # either create the transfer or (if it resolves to nil) destroy
    # the schedule.
    def process(schedule)
      data = @resolver.resolve(schedule)
      if data.nil?
        schedule.group.log "Destroying obsolete schedule #{schedule.name}"
        schedule.destroy
        return
      end
      log_input_url = data.delete("log_input_url")
      unless log_input_url.nil?
        schedule.group.update(log_input_url: log_input_url)
      end

      schedule.db.transaction do
        Transferatu::Mediators::Transfers::Creator
          .run(schedule:  schedule,
               group:     schedule.group,
               from_type: data["from_type"],
               from_url:  data["from_url"],
               from_name: data["from_name"],
               to_type:   data["to_type"],
               to_url:    data["to_url"],
               to_name:   data["to_name"],
               options:   data["options"] || {})
        schedule.mark_executed
        Transferatu::Mediators::Schedules::Expirer
          .run(schedule: schedule, expire_at: Time.now)

        schedule.group.log "Created scheduled transfer for #{schedule.name}"
      end
    end
  end
end
