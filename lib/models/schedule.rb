module Transferatu
  class Schedule < Sequel::Model
    plugin :timestamps
    plugin :paranoid

    many_to_one :group
    one_to_many :transfers

    # Schedules that are expected to start a transfer at the given
    # time and have not started any transfers in the twelve hours
    # before this time
    def_dataset_method(:pending_for) do |time, limit: 250|
      self.with_sql(<<-EOF, time: time, limit: limit)
SELECT
  s.*
FROM
  schedules s INNER JOIN groups g ON s.group_id = g.uuid
    LEFT OUTER JOIN transfers t ON t.schedule_id = s.uuid
      AND t.created_at > (timestamptz :time - interval '12 hours')
WHERE
  ARRAY[extract(dow from (:time at time zone timezone)::timestamptz)::smallint] && dows
    AND hour = extract(hour from (:time at time zone timezone)::timestamptz)
    AND t.uuid IS NULL
    AND s.deleted_at IS NULL
LIMIT
  :limit
EOF
    end
  end
end
