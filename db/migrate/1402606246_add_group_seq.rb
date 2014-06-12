Sequel.migration do
  up do
    alter_table :groups do
      add_column :transfer_count, :integer
    end
    alter_table :transfers do
      add_column :transfer_num, :integer
    end
    execute <<-EOF
CREATE or replace FUNCTION transfers_insert_trigger_fn() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.transfer_num IS NULL THEN
    UPDATE groups SET transfer_count = transfer_count + 1
      WHERE groups.uuid = NEW.group_id RETURNING transfer_count INTO NEW.transfer_num;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE PLPGSQL VOLATILE;

CREATE TRIGGER transfers_insert_trigger BEFORE INSERT ON transfers
  FOR EACH ROW EXECUTE PROCEDURE transfers_insert_trigger_fn();
EOF
  end

  down do
    execute <<-EOF
DROP FUNCTION transfers_insert_trigger_fn() CASCADE;
EOF
    alter_table :groups do
      drop_column :transfer_count
    end
    alter_table :transfers do
      drop_column :transfer_num
    end    
  end
end
