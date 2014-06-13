module Transferatu::Serializers
  class Transfer < Base
    structure(:default) do |transfer|
      {
        uuid:     transfer.uuid,
        type:     transfer.type,
        from_url: transfer.from_url,
        to_url:   transfer.to_url,
        group: {
          uuid: transfer.group.uuid,
          name: transfer.group.name
        },
        options:  transfer.options,
        logplex_token: transfer.logplex_token,

        transfer_num:    transfer.transfer_num,
        succeeded:       transfer.succeeded,
        source_bytes:    transfer.source_bytes,
        processed_bytes: transfer.processed_bytes,

        created_at:  transfer.created_at,
        started_at:  transfer.started_at,
        updated_at:  transfer.updated_at,
        canceled_at: transfer.canceled_at,
        finished_at: transfer.finished_at,
        deleted_at:  transfer.deleted_at,
        purged_at:   transfer.purged_at
      }
    end
  end
end
