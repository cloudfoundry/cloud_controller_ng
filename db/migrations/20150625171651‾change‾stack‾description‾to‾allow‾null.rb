Sequel.migration do
  up do
    alter_table(:stacks) do
      set_column_allow_null :description
    end
  end
  down do
    alter_table(:stacks) do
      set_column_not_null :description
    end
  end
end
