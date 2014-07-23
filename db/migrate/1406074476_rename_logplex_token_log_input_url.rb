Sequel.migration do
  up do
    alter_table(:groups) do
      rename_column :logplex_token, :log_input_url
    end
  end

  down do
    alter_table(:groups) do
      rename_column :log_input_url, :logplex_token
    end    
  end
end
