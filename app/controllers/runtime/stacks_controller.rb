module VCAP::CloudController
  class StacksController < RestController::ModelController
    define_attributes do
      attribute  :name,           String
      attribute  :description,    String
    end

    query_parameters :name

    get path, :enumerate
    get path_guid, :read
  end
end
