module Transferatu::Serializers
  class Schedule < Base
    structure(:default) do |schedule|
      {
        uuid: schedule.uuid,
        name: schedule.name,

        hour:     schedule.hour,
        days:     schedule.dows.map { |d| Date::DAYNAMES[d] },
        timezone: schedule.timezone,

        created_at: schedule.created_at,
        updated_at: schedule.updated_at,
        deleted_at: schedule.deleted_at
      }
    end
  end
end
