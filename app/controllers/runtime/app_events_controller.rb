module VCAP::CloudController
  rest_controller :AppEvents do
    define_attributes do
      to_one    :app
      attribute :instance_guid, String
      attribute :instance_index, Integer
      attribute :exit_status, Integer
      attribute :timestamp, String
    end

    query_parameters :timestamp, :app_guid
  end
end