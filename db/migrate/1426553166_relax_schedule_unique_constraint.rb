Sequel.migration do
  change do
    alter_table(:schedules) do
      add_index %i(group_id name), :unique=>true, where: Sequel.lit('deleted_at IS NULL')
      drop_constraint :unique_active_within_group
    end
  end
end
