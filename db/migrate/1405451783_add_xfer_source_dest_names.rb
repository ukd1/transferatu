Sequel.migration do
  up do
    alter_table(:transfers) do
      add_column :from_name, :text
      add_column :to_name, :text
    end
  end

  down do
    alter_table(:transfers) do
      drop_column :from_name
      drop_column :to_name
    end
  end
end
