Sequel.migration do
  up do
    alter_table :apps do
      set_column_default :instances, 1
    end
  end

  down do
    alter_table :apps do
      set_column_default :instances, 0
    end
  end
end
