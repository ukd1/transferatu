Sequel.migration do
  up do
    alter_table(:users) do
      drop_column :token
    end
  end

  down do
    alter_table(:users) do
      add_column :token, :text
    end
  end
end
