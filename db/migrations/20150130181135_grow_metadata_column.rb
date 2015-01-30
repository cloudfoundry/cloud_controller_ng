Sequel.migration do
  up do
    alter_table :apps do
      set_column_type :metadata, String, size: 4095, text: true
    end
  end

  down do
    alter_table :apps do
      set_column_type :metadata, String
    end
  end
end
