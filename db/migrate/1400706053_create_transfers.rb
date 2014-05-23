Sequel.migration do
  change do
    self.execute <<-EOF
    CREATE FUNCTION scheme(url text) RETURNS text AS
    $$
        SELECT substring($1 from '.*?(?=:)');
    $$ LANGUAGE SQL STABLE;
EOF
    create_table(:transfers) do
      uuid         :uuid, default: Sequel.function(:uuid_generate_v4), primary_key: true
      timestamptz  :created_at, default: Sequel.function(:now), null: false
      timestamptz  :scheduled_at
      timestamptz  :updated_at
      timestamptz  :finished_at
      boolean      :succeeded
      foreign_key  :user_id, :users, null: false
      text         :logplex_token
      text         :from_scheme, null: false
      text         :from_url, null: false
      text         :to_scheme, null: false
      text         :to_url, null: false
      json         :options, null: false, default: '{}'
      bigint       :source_bytes
      bigint       :bytes
      timestamptz  :deleted_at
      timestamptz  :purged_at
    end
  end
end
