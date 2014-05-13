Sequel.migration do
  change do
    self.execute <<-EOF
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOF

    create_table :transfers do
      uuid :uuid, default: 'uuid_generate_v4()'.lit, primary_key: true
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      text :from_url, null: false
      text :s3_key, null: false
      bigint :db_size_bytes, null: false
      int :exit_status
      timestamptz :finished_at
    end

    create_table :logs do
      uuid :uuid, default: 'uuid_generate_v4()'.lit, primary_key: true
      foreign_key :transfer_id, :transfers, type: :uuid, null: false
      timestamptz :created_at, null: false, default: Sequel.function(:now)
      text :message, null: false
    end
  end
end
