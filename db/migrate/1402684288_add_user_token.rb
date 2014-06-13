Sequel.migration do
  up do
    alter_table :users do
      add_column :token, :text, null: false
      set_column_not_null :name
      drop_index :name
      add_unique_constraint(:name, name: :unique_name)
    end
  end

  down do
    drop_column :token
    drop_constraint(:unique_name)
    set_column_allow_null :name
    add_index :name
  end
end
