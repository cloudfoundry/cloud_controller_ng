Sequel.migration do
  up do
    if indexes(:services)[:services_label_provider_index]
      alter_table :services do
        drop_index :label, name: :services_label_provider_index
      end
    end
  end

  down do
    # This migration cannot be rolled back
  end
end
