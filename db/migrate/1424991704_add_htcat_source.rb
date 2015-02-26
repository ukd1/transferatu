Sequel.migration do
  no_transaction

  up do
    execute "ALTER TYPE target_type ADD VALUE 'htcat'"
  end

  down do
    raise Sequel::Error, 'irreversible migration'
  end
end
