Sequel.migration do
  change do
    alter_table(:services) do
      add_column :bindable, TrueClass, null: false, default: true
      set_column_default :bindable, nil # Require "bindable" for future rows
    end
  end
end
