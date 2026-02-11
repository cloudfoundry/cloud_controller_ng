Sequel.migration do
  up do
    # In this PR https://github.com/cloudfoundry/cloud_controller_ng/pull/1193
    # we are performing an API level validation on the length of description
    # fields in the service broker catalog. However we do not want to break
    # older brokers that may have long descriptions. Here we are disabling
    # rubocop from checking the string size.
    alter_table :services do
      set_column_type :description, String, text: true
    end

    alter_table :service_plans do
      set_column_type :description, String, text: true
    end
  end
end
