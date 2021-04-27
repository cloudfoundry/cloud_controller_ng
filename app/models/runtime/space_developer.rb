module VCAP::CloudController
  class SpaceDeveloper < Sequel::Model(:spaces_developers)
    include SpaceRoleMixin

    def type
      @type ||= RoleTypes::SPACE_DEVELOPER
    end
  end
end
