Sequel.migration do
  up do
    alter_table :logs do
      rename_column :severity, :level
    end
  end

  down do
    alter_table :logs do
      rename_column :level, :severity
    end
  end
end
