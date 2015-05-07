Sequel.migration do
  change do
    alter_table(:logs) do
      add_index(%i(foreign_uuid created_at))
    end
  end
end
