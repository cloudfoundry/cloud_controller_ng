module VCAP::CloudController
  class SpaceAuditor < Sequel::Model(:spaces_auditors)
    include SpaceRoleMixin

    def type
      @type ||= RoleTypes::SPACE_AUDITOR
    end
  end
end
