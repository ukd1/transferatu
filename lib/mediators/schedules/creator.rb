module Transferatu
  module Mediators::Schedules
    class Creator < Mediators::Base
      def initialize(group:, name:, callback_url:, hour:, days:, timezone:)
        @group = group
        @name = name
        @callback_url = callback_url
        @hour = hour
        @days = days
        @tz = timezone
      end

      def call
        dows = @days.map { |dayname| to_dow(dayname) }.uniq
        # Ensure that we have a valid timezone, and forbid any
        # abbrevations except UTC to avoid ambiguities.
        legit_tz = Schedule.db.fetch(<<-EOF, tz: @tz).first[:is_legit]
SELECT
  :tz IN (SELECT name FROM pg_timezone_names) AND
    (:tz NOT IN (SELECT abbrev FROM pg_timezone_abbrevs) OR :tz = 'UTC') AS is_legit
EOF
        unless legit_tz
          raise ArgumentError, <<-EOF
Unknown time zone: '#{@tz}'; check

  http://en.wikipedia.org/wiki/List_of_tz_database_time_zones

for a list of supported time zones and use the full time zone name
EOF
        end

        begin
          parsed = URI.parse(@callback_url)
          if parsed.scheme != 'https'
            raise ArgumentError, "Unsupported callback_url scheme #{parsed.scheme}; must be https"
          end
        rescue URI::InvalidURIError
          raise ArgumentError, "Could not parse callback_url"
        end

        @group.add_schedule(name: @name, callback_url: @callback_url,
                            hour: @hour, dows: dows, timezone: @tz)
      end

      private

      def to_dow(dayname)
        dow = Date::DAYNAMES.index(dayname)
        if dow.nil?
          raise ArgumentError, "Unknown day name: #{dayname}"
        end
        dow
      end
    end
  end
end
