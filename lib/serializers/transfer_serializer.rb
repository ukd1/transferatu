module Transferatu::Serializers
  class Transfer < Base
    structure(:default) do |transfer|
      {
        uuid: transfer.uuid,
        type: transfer.type,
        num:  transfer.transfer_num,

        from_url:  transfer.from_url,
        to_url:    transfer.to_url,
        options:   transfer.options,
        log_token: transfer.logplex_token,

        group: {
          uuid: transfer.group.uuid,
          name: transfer.group.name
        },

        source_bytes:    transfer.source_bytes,
        processed_bytes: transfer.processed_bytes,
        succeeded:       transfer.succeeded,

        created_at:  transfer.created_at,
        started_at:  transfer.started_at,
        canceled_at: transfer.created_at,
        updated_at:  transfer.updated_at,
        finished_at: transfer.finished_at,
        deleted_at:  transfer.deleted_at,
        purged_at:   transfer.purged_at
      }
    end
  end
end
