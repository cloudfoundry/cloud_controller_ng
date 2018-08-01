Sequel.migration do
  up do
    alter_table :tasks do
      set_column_type :command, String, text: true
    end
  end

  down do
    alter_table :tasks do
      set_column_type :command, String
    end
  end
end
