Sequel.migration do
  change do
    alter_table :apps do
      add_column :kill_after_multiple_restarts, :boolean, default: false
    end
  end
end
