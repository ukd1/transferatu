Sequel.migration do
  up do
    execute "CREATE UNIQUE INDEX singleton_app_status ON app_status((1));"
  end

  down do
    execute "DROP INDEX singleton_app_status;"
  end
end
