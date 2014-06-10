Sequel.migration do
  up do
    alter_table :transfers do
      add_column :type, :text, null: false
    end
  end

  down do
    alter_table :transfers do
      drop_column :type
    end    
  end
end
