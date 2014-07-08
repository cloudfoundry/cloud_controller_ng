module VCAP::CloudController
  class StacksController < RestController::ModelController
    query_parameters :name

    get path, :enumerate
    get path_guid, :read
  end
end
