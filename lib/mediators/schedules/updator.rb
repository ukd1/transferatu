require_relative 'helpers'

module Transferatu
  module Mediators::Schedules
    class Updator < Mediators::Base
      include ScheduleValidator

      def initialize(schedule:, name:, callback_url:,
                     hour:, days:, timezone:,
                     retain_weeks:, retain_months:)
        @schedule = schedule
        @name = name
        @callback_url = callback_url
        @hour = hour
        @days = days
        @tz = timezone

        @retain_weeks = retain_weeks
        @retain_months = retain_months
      end

      def call
        verify_timezone(@tz)
        verify_callback(@callback_url)
        sched_opts = { name: @name, callback_url: @callback_url,
                       hour: @hour, dows: map_days(@days), timezone: @tz }

        unless @retain_weeks.nil?
          sched_opts.merge!(retain_weeks: @retain_weeks.to_i)
        end
        unless @retain_months.nil?
          sched_opts.merge!(retain_months: @retain_months.to_i)
        end
        @schedule.update(sched_opts)
        @schedule
      end
    end
  end
end
