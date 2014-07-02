module Transferatu::Serializers
  class Group < Base
    structure(:default) do |group|
      {
        uuid:           group.uuid,
        name:           group.name,
        transfer_count: group.transfer_count,

        created_at: group.created_at,
        updated_at: group.updated_at,
        deleted_at: group.deleted_at
      }
    end
  end
end
