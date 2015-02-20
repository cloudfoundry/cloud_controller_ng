Sequel.migration do
  up do
    alter_table :apps do
      drop_column :kill_after_multiple_restarts
    end
  end

  down do
    alter_table :apps do
      add_column :kill_after_multiple_restarts, :boolean, default: false
    end
  end
end
