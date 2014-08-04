Sequel.migration do
  up do
    alter_table :transfers do
      rename_column :from_url, :unencrypted_from_url
      rename_column :to_url, :unencrypted_to_url

      add_column :from_url, :text
      add_column :to_url, :text
    end
    alter_table :users do
      rename_column :token, :unencrypted_token

      add_column :token, :text
    end
    alter_table :groups do
      rename_column :log_input_url, :unencrypted_log_input_url

      add_column :log_input_url, :text
    end
  end

  down do
    raise Sequel::Error, 'irreversible migration'
  end
end
