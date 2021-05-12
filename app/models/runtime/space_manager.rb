module VCAP::CloudController
  class SpaceManager < Sequel::Model(:spaces_managers)
    include SpaceRoleMixin

    def type
      @type ||= RoleTypes::SPACE_MANAGER
    end
  end
end
