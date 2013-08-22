module VCAP::CloudController
  rest_controller :Stacks do
    disable_default_routes

    define_attributes do
      attribute  :name,           String
      attribute  :description,    String
    end

    query_parameters :name

    get path, :enumerate
    get path_guid, :read
  end
end
