Sequel.migration do
  change do
    create_table(:exec_infos) do
      timestamptz  :created_at, default: Sequel.function(:now), null: false
      uuid         :worker_id, null: false
      uuid         :foreign_uuid, null: false
      text         :process_type, null: false
      integer      :rss_kb, null: false
      integer      :vsz_kb, null: false
      float        :pcpu, null: false
    end
  end
end
