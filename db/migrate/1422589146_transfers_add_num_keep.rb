Sequel.migration do
  change do
    alter_table(:transfers) do
      add_column :num_keep, :integer, default: 5, null: false
    end
  end
end
