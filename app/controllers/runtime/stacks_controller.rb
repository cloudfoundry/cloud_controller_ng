module VCAP::CloudController
  class StacksController < RestController::ModelController
    query_parameters :name

    get path, :enumerate
    get path_guid, :read
    delete path_guid, :delete

    def delete(guid)
      obj = find_guid_and_validate_access(:delete, guid)
      do_delete(obj)
    end
  end
end
