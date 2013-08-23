module VCAP::CloudController
  rest_controller :Events do
    define_attributes do
      to_one :space
    end

    query_parameters :timestamp, :type
  end
end