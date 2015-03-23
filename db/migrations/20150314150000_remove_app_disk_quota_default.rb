Sequel.migration do
  up do
    alter_table(:apps) do
      set_column_default :disk_quota, nil
    end
  end

  down do
    alter_table(:apps) do
      set_column_default :disk_quota, 256
    end
  end
end
