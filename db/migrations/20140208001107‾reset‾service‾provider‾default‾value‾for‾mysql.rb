Sequel.migration do
  up do
    alter_table :services do
      set_column_default :provider, ''
    end
  end

  down do
    # no-op
  end
end
