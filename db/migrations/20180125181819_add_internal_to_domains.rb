Sequel.migration do
  change do
    alter_table :domains do
      add_column :internal, :boolean, default: false
    end
  end
end
