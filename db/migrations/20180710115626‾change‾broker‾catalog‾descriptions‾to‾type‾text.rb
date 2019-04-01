Sequel.migration do
  up do
    # In this PR https://github.com/cloudfoundry/cloud_controller_ng/pull/1193
    # we are performing an API level validation on the length of description
    # fields in the service broker catalog. However we do not want to break
    # older brokers that may have long descriptions. Here we are disabling
    # rubocop from checking the string size.
    alter_table :services do
      # rubocop:disable Migration/IncludeStringSize
      set_column_type :description, String, text: true
      # rubocop:enable Migration/IncludeStringSize
    end

    alter_table :service_plans do
      # rubocop:disable Migration/IncludeStringSize
      set_column_type :description, String, text: true
      # rubocop:enable Migration/IncludeStringSize
    end
  end
end
