module Transferatu
  module Mediators::Schedules
    module ScheduleValidator
      def map_days(days)
        days.map { |dayname| to_dow(dayname) }.uniq
      end

      def to_dow(dayname)
        dow = Date::DAYNAMES.index(dayname)
        if dow.nil?
          raise ArgumentError, "Unknown day name: #{dayname}"
        end
        dow
      end

      def verify_timezone(tz)
        # Ensure that we have a valid timezone, and forbid any
        # abbrevations except UTC to avoid ambiguities.
        legit_tz = Schedule.db.fetch(<<-EOF, tz: tz).first[:is_legit]
SELECT
  :tz IN (SELECT name FROM pg_timezone_names) AND
    (:tz NOT IN (SELECT abbrev FROM pg_timezone_abbrevs) OR :tz = 'UTC') AS is_legit
EOF
        unless legit_tz
          raise ArgumentError, <<-EOF
Unknown time zone: '#{tz}'; check

  http://en.wikipedia.org/wiki/List_of_tz_database_time_zones

for a list of supported time zones and use the full time zone name
EOF
        end
      end

      def verify_callback(url)
        begin
          parsed = URI.parse(url)
          if parsed.scheme != 'https'
            raise ArgumentError, "Unsupported callback_url scheme #{parsed.scheme}; must be https"
          end
        rescue URI::InvalidURIError
          raise ArgumentError, "Could not parse callback_url"
        end
      end
    end
  end
end
