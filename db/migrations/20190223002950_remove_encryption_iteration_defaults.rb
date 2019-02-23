Sequel.migration do
  change do
    alter_table(:apps) do
      set_column_default :encryption_iterations, 100_000
    end

    alter_table(:buildpack_lifecycle_buildpacks) do
      set_column_default :encryption_iterations, 100_000
    end

    alter_table(:buildpack_lifecycle_data) do
      set_column_default :encryption_iterations, 100_000
    end

    alter_table(:droplets) do
      set_column_default :encryption_iterations, 100_000
    end

    alter_table(:env_groups) do
      set_column_default :encryption_iterations, 100_000
    end

    alter_table(:packages) do
      set_column_default :encryption_iterations, 100_000
    end

    alter_table(:revisions) do
      set_column_default :encryption_iterations, 100_000
    end

    alter_table(:tasks) do
      set_column_default :encryption_iterations, 100_000
    end

    alter_table(:service_bindings) do
      set_column_default :encryption_iterations, 100_000
    end

    alter_table(:service_brokers) do
      set_column_default :encryption_iterations, 100_000
    end

    alter_table(:service_instances) do
      set_column_default :encryption_iterations, 100_000
    end

    alter_table(:service_keys) do
      set_column_default :encryption_iterations, 100_000
    end

    alter_table(:encryption_key_sentinels) do
      set_column_default :encryption_iterations, 100_000
    end
  end
end
