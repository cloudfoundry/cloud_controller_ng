Sequel.migration do
  up do
    create_table :legacy_service_account_names do
      primary_key :id, name: :legacy_service_account_names_pkey
      String :name, size: 63, null: false
      index :name, unique: true, name: :legacy_service_account_names_unique
    end
    from(:service_account_names).select(:name).distinct.each do |reservation|
      from(:legacy_service_account_names).insert(name: reservation[:name])
    end
  end

  down do
    drop_table :legacy_service_account_names
  end
end
