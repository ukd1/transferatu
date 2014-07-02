Sequel.migration do
  up do
    alter_table :groups do
      set_column_default :transfer_count, 0
    end
  end

  down do
    alter_table :groups do
      # technically the default was previously unset
      set_column_default :transfer_count, nil
    end    
  end
end
