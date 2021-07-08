module VCAP::CloudController
  class SpaceSupporter < Sequel::Model(:spaces_application_supporters)
    include SpaceRoleMixin

    def type
      @type ||= RoleTypes::SPACE_SUPPORTER
    end
  end
end
