Sequel.migration do
  up do
    alter_table(:apps) do
      set_column_default :memory, nil
    end
  end

  down do
    alter_table(:apps) do
      set_column_default :memory, 256
    end
  end
end
