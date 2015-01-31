Sequel.migration do
  change do
    alter_table(:schedules) do
      add_unique_constraint([:group_id, :name], name: :unique_active_within_group,
                            where: Sequel.lit('deleted_at IS NULL'))
      drop_constraint(:unique_within_group)
    end
  end
end
