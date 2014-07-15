Sequel.migration do
  up do
    execute "CREATE TYPE target_type AS ENUM('pg_dump', 'pg_restore', 'gof3r')"

    alter_table(:transfers) do
      add_column :from_type, :target_type
      add_column :to_type, :target_type
    end

    execute <<-EOF
UPDATE
  transfers
SET
  from_type = split_part(type, ':', 1)::target_type,
  to_type = split_part(type, ':', 2)::target_type
EOF

    alter_table(:transfers) do
      drop_column :type
      set_column_not_null :from_type
      set_column_not_null :to_type
    end
  end

  down do
    alter_table(:transfers) do
      add_column(:type, :text)
    end

    execute <<-EOF
UPDATE
  transfers
SET
  type = from_type || ':' || to_type
EOF

    alter_table(:transfers) do
      drop_column :from_type
      drop_column :to_type
    end
    
    execute "DROP TYPE target_type"
  end
end
