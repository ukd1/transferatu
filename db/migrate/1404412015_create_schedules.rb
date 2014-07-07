Sequel.migration do
  change do
    create_table(:schedules) do
      uuid        :uuid, default: Sequel.function(:uuid_generate_v4), primary_key: true
      timestamptz :created_at, default: Sequel.function(:now), null: false
      timestamptz :updated_at
      timestamptz :deleted_at
      foreign_key :group_id, :groups, type: :uuid
      text        :name, null: false
      text        :callback_url, null: false
      smallint    :hour, null: false
      column      :dows, "smallint[]", null: false
      text        :timezone, null: false, default: 'UTC'
      check Sequel.lit("hour between 0 and 23")
    end

    alter_table(:transfers) do
      add_foreign_key :schedule_id, :schedules, type: :uuid
    end
  end
end
