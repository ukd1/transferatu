Sequel.migration do
  change do
    self.execute <<-EOF
    CREATE TYPE log_severity AS ENUM ('info', 'warning', 'error');
EOF
    create_table(:logs) do
      uuid         :foreign_uuid, null: false
      timestamptz  :created_at, default: Sequel.function(:now), null: false
      text         :message, null: false
      log_severity :severity, null: false
    end
  end
end
