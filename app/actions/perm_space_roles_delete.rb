module VCAP::CloudController
  class PermSpaceRolesDelete
    def initialize(client)
      @client = client
    end

    def delete(space)
      @client = client.rehydrate
      VCAP::CloudController::Roles::SPACE_ROLE_NAMES.each do |role|
        begin
          client.delete_space_role(role: role, space_id: space.guid)
        rescue
          return [CloudController::Errors::ApiError.new_from_details('SpaceRolesDeletionFailed', space.name)]
        end
      end
      []
    end

    def timeout_error(space)
      CloudController::Errors::ApiError.new_from_details('SpaceRolesDeletionTimeout', space.name)
    end

    private

    attr_reader :client
  end
end
