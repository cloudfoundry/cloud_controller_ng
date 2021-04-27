module VCAP::CloudController
  class SpaceApplicationSupporter < Sequel::Model(:spaces_application_supporters)
    include SpaceRoleMixin

    def type
      @type ||= RoleTypes::SPACE_APPLICATION_SUPPORTER
    end
  end
end
