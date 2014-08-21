module Transferatu
  class Schedule < Sequel::Model
    plugin :timestamps
    plugin :paranoid

    many_to_one :group
    one_to_many :transfers

    def_dataset_method(:pending_for) do |time|
      self.with_sql(<<-EOF, time: time)
SELECT
  s.*
FROM
  schedules s INNER JOIN groups g ON s.group_id = g.uuid
    LEFT OUTER JOIN transfers t ON t.schedule_id = s.uuid
      AND t.created_at > (timestamptz :time - interval '12 hours')
WHERE
  ARRAY[extract(dow from (:time at time zone timezone)::timestamptz)::smallint] && dows
    AND hour = extract(hour from (:time at time zone timezone)::timestamptz)
    AND t.uuid IS NULL;
EOF
    end

  end
end
