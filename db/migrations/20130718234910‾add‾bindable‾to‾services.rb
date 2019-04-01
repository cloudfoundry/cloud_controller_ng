Sequel.migration do
  change do
    alter_table(:services) do
      add_column :bindable, TrueClass
    end

    from(:services).update(bindable: true)

    alter_table(:services) do
      set_column_not_null :bindable
    end
  end
end
