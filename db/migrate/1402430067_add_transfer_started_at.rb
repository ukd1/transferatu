Sequel.migration do
  up do
    alter_table :transfers do
      add_column :started_at, :timestamptz
    end
  end

  down do
    alter_table :transfers do
      drop_column :started_at
    end
  end
end
