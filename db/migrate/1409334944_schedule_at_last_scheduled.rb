Sequel.migration do
  up do
    alter_table(:schedules) do
      add_column(:last_scheduled_at, :timestamptz)
    end
  end

  down do
    alter_table(:schedules) do
      drop_column(:last_scheduled_at)
    end
  end
end
