Sequel.migration do

  no_transaction

  change do
    alter_table(:transfers) do
      add_index :group_id, name: 'active_group_transfers_idx', where: { deleted_at: nil }, concurrently: true
    end
  end
end
