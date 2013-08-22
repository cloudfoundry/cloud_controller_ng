module VCAP::CloudController
  rest_controller :Events do
    define_attributes do
      to_one :space
    end
  end
end