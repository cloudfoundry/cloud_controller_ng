Sequel.migration do
  up do
    alter_table :services do
      set_column_type :tags, String, text: true
    end
  end

  down do
    alter_table :services do
      set_column_type :tags, 'varchar(255)'
    end
  end
end
