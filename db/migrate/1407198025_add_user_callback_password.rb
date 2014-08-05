Sequel.migration do
  up do
    alter_table :users do
      add_column :callback_password, :text
    end
  end

  down do
    alter_table :users do
      drop_column :callback_password
    end
  end
end
