Sequel.migration do
  change do
    create_table(:worker_statuses) do
      uuid         :uuid, primary_key: true
      timestamptz  :created_at, default: Sequel.function(:now), null: false
      timestamptz  :updated_at
      text         :dyno_name, null: false
      inet         :host, null: false
      uuid         :transfer_id
    end
  end
end
