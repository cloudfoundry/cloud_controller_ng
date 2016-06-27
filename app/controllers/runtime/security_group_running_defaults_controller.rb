module VCAP::CloudController
  class SecurityGroupRunningDefaultsController < RestController::ModelController
    def self.model
      SecurityGroup
    end

    def self.path
      "#{V2_ROUTE_PREFIX}/config/running_security_groups"
    end

    def self.not_found_exception(guid, _find_model)
      CloudController::Errors::ApiError.new_from_details('SecurityGroupRunningDefaultInvalid', guid)
    end

    get path, :enumerate

    put path_guid, :update
    def update(guid)
      obj = find_guid_and_validate_access(:update, guid)

      model.db.transaction do
        obj.lock!
        obj.update_from_hash({ 'running_default' => true })
      end

      [
        HTTP::OK,
        object_renderer.render_json(self.class, obj, @opts)
      ]
    end

    delete path_guid, :delete
    def delete(guid)
      obj = find_guid_and_validate_access(:delete, guid)

      model.db.transaction do
        obj.lock!
        obj.update_from_hash({ 'running_default' => false })
      end

      [
        HTTP::NO_CONTENT
      ]
    end

    def read(_)
      raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') unless roles.admin?
      super
    end

    def enumerate
      raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') unless roles.admin?
      super
    end

    private

    def filter_dataset(dataset)
      dataset.filter(running_default: true)
    end
  end
end
