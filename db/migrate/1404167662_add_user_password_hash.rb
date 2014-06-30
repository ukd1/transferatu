Sequel.migration do
  up do
    alter_table :users do
      add_column :password_hash, :text
    end
  end

  down do
    alter_table :users do
      drop_column :password_hash
    end    
  end
end
