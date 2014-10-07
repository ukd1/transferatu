Sequel.migration do
  change do
    alter_table(:groups) do
      add_column :backup_limit, :integer
    end
  end
end
