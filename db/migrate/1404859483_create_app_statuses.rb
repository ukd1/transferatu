Sequel.migration do
  up do
    create_table(:app_status) do
      # strictly speaking, we don't need a primary key here, but it
      # makes it easier for Sequel to work with the model if we
      # include one
      uuid         :uuid, default: Sequel.function(:uuid_generate_v4), primary_key: true
      timestamptz  :updated_at, null: false
      bool         :quiesced, null: false
    end
    execute "INSERT INTO app_status(updated_at, quiesced) VALUES(now(), false)"
  end

  down do
    drop_table(:app_status)
  end
end
