Sequel.migration do
  change do
    alter_table(:transfers) do
      add_index(:created_at, name: :pending_transfers_idx, where: Sequel.lit("started_at IS NULL"))
    end
  end
end
