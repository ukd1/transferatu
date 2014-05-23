Sequel.migration do
  change do
    self.execute <<-EOF
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOF
    create_table(:users) do
      uuid         :uuid, default: Sequel.function(:uuid_generate_v4), primary_key: true
      timestamptz  :created_at, default: Sequel.function(:now), null: false
      timestamptz  :updated_at
      timestamptz  :deleted_at
      text         :name

      index :name
    end
  end
end
