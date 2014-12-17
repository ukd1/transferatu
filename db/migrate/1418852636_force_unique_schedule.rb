Sequel.migration do
  up do
    alter_table(:schedules) do
      add_unique_constraint([:group_id, :name], name: :unique_within_group)
    end
  end

  down do
    drop_constraint(:unique_within_group)
  end
end
