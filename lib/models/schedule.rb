module Transferatu
  class Schedule < Sequel::Model
    plugin :timestamps
    plugin :paranoid

    many_to_one :group
    one_to_many :transfers

    def mark_executed
      update(last_scheduled_at: Time.now)
    end

    # Schedules that are expected to start a transfer at the given
    # time and have not started any transfers in the twelve hours
    # before this time
    def_dataset_method(:pending_for) do |time, limit: 250|
      self.with_sql(<<-EOF, time: time, limit: limit)
SELECT
  s.*
FROM
  schedules s
WHERE
  ARRAY[extract(dow from (:time at time zone timezone)::timestamptz)::smallint] && dows
    AND hour = extract(hour from (:time at time zone timezone)::timestamptz)
    AND (s.last_scheduled_at IS NULL
          OR s.last_scheduled_at < (timestamptz :time - interval '12 hours'))
    AND s.deleted_at IS NULL
LIMIT
  :limit
EOF
    end
  end
end
