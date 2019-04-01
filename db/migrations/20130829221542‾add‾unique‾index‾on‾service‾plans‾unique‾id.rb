Sequel.migration do
  change do
    plans = select(:id, :unique_id).from(:service_plans)
    plans.each do |plan|
      unless plan[:unique_id].present?
        id = plan[:id]
        unique_id = SecureRandom.uuid
        run "UPDATE service_plans SET unique_id = '#{unique_id}' WHERE guid = '#{id}' AND (unique_id IS NULL OR TRIM(unique_id) = '')"
      end
    end

    alter_table :service_plans do
      set_column_not_null :unique_id
    end
  end
end
