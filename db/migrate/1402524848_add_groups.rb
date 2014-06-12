Sequel.migration do
  up do
    create_table(:groups) do
      uuid         :uuid, default: Sequel.function(:uuid_generate_v4), primary_key: true
      timestamptz  :created_at, default: Sequel.function(:now), null: false
      timestamptz  :updated_at
      timestamptz  :deleted_at
      uuid         :user_id, null: false
      text         :name, null: false, default: 'default'
      unique([:user_id, :name])
    end

    execute(<<-EOF)
INSERT INTO groups(user_id, name) SELECT DISTINCT user_id, "group" FROM transfers;
EOF

    alter_table :transfers do
      rename_column :group, :group_id
      set_column_type :group_id, :uuid, using: Sequel.function(:uuid_generate_v4)
      add_foreign_key([:group_id], :groups)
      drop_column :user_id
    end
  end

  down do
    alter_table :transfers do
      add_column :user_id, :uuid
      drop_foreign_key [:group_id]
      set_column_type :group_id, :text
      rename_column :group_id, :group
    end

    execute(<<-EOF)
UPDATE transfers SET group = groups.name, user_id = groups.user_id
  FROM groups WHERE transfers.group = groups.uud
EOF

    drop_table :groups
  end
end
