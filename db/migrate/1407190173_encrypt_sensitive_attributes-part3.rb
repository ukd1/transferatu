Sequel.migration do
  up do
    alter_table :transfers do
      drop_column :unencrypted_from_url
      drop_column :unencrypted_to_url

      set_column_not_null :from_url
      set_column_not_null :to_url
    end
    alter_table :users do
      drop_column :unencrypted_token

      set_column_not_null :token
    end
    alter_table :groups do
      drop_column :unencrypted_log_input_url

      set_column_not_null :log_input_url
    end
  end

  down do
    raise Sequel::Error, 'irreversible migration'
  end
end
