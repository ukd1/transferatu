module Transferatu
  module Mediators::Schedules
    class Expirer < Mediators::Base
      def initialize(schedule: schedule, expire_at: expire_at)
        @schedule = schedule
        @expire_at = expire_at
      end

      def call
        # We want to keep several recent backups, and then space out the
        # less recent ones so we cover a larger time range of having a
        # backup available for that time period.
        #
        # So, our strategy is to delete everything that's older than a
        # week, *except* the oldest backup newer than 2, 3, 4, 5
        # weeks. We accept a reference time instead of using now() for
        # repeatability and testing.
        expired = Transfer.with_sql(<<-EOF, schedule_id: @schedule.uuid, expire_at: @expire_at).all
SELECT
  t.*
FROM
  transfers t
WHERE
  t.schedule_id = :schedule_id AND deleted_at IS NULL
    AND t.created_at < (timestamptz :expire_at - interval '1 week')
    AND t.uuid NOT IN
(WITH thresholds AS (
  SELECT
    ts as threshold
  FROM
    generate_series(timestamptz :expire_at - interval '5 weeks', :expire_at, interval '1 week') ts
)
SELECT
  DISTINCT ON (threshold) t.uuid
FROM
  transfers t INNER JOIN thresholds th on t.created_at > th.threshold
WHERE
  t.schedule_id = :schedule_id AND deleted_at IS NULL
ORDER BY
  threshold, t.created_at)
EOF
        expired.each do |t|
          t.log("Expiring scheduled transfer for #{@schedule.name} captured on #{t.created_at}")
          t.destroy
        end
      end
    end
  end
end
