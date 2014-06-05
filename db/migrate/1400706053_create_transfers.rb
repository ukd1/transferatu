Sequel.migration do
  change do
    create_table(:transfers) do
      uuid         :uuid, default: Sequel.function(:uuid_generate_v4), primary_key: true
      timestamptz  :created_at, default: Sequel.function(:now), null: false
      timestamptz  :updated_at
      timestamptz  :canceled_at
      timestamptz  :finished_at
      boolean      :succeeded
      uuid         :user_id, null: false
      text         :group, null: false
      text         :logplex_token
      text         :from_url, null: false
      text         :to_url, null: false
      json         :options, null: false, default: '{}'
      bigint       :source_bytes
      bigint       :processed_bytes, null: false, default: 0
      timestamptz  :deleted_at
      timestamptz  :purged_at
    end
  end
end
