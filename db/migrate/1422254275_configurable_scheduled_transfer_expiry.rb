Sequel.migration do
  change do
    alter_table(:schedules) do
      add_column :retain_weeks, :integer, default: 5
      add_column :retain_months, :integer, default: 0
    end
  end
end
