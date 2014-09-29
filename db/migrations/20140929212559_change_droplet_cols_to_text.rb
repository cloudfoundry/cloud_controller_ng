Sequel.migration do
  up do
    alter_table(:droplets) do
      set_column_type(:detected_start_command, 'text')
      set_column_type(:execution_metadata, 'text')
    end
  end
end
