Sequel.migration do
  no_transaction

  up do
    %i[apps droplets builds].each do |table|
      if database_type == :postgres
        transaction do
          alter_table(table) do
            add_constraint({ name: :"#{table}_lifecycle_type_not_null", not_valid: true }) do
              Sequel.lit('lifecycle_type IS NOT NULL')
            end
          end
        end

        VCAP::Migration.with_concurrent_timeout(self) do
          run("ALTER TABLE #{table} VALIDATE CONSTRAINT #{table}_lifecycle_type_not_null")
        end
      else
        alter_table(table) { set_column_not_null :lifecycle_type }
      end
    end
  end

  down do
    %i[apps droplets builds].each do |table|
      if database_type == :postgres
        alter_table(table) { drop_constraint(:"#{table}_lifecycle_type_not_null") }
      else
        alter_table(table) { set_column_allow_null :lifecycle_type }
      end
    end
  end
end
