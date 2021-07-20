module VCAP::CloudController
  class RoleTypes
    SPACE_AUDITOR = 'space_auditor'.freeze
    SPACE_MANAGER = 'space_manager'.freeze
    SPACE_DEVELOPER = 'space_developer'.freeze
    SPACE_SUPPORTER = 'space_supporter'.freeze
    ORGANIZATION_AUDITOR = 'organization_auditor'.freeze
    ORGANIZATION_MANAGER = 'organization_manager'.freeze
    ORGANIZATION_BILLING_MANAGER = 'organization_billing_manager'.freeze
    ORGANIZATION_USER = 'organization_user'.freeze

    ORGANIZATION_ROLES = [
      ORGANIZATION_AUDITOR,
      ORGANIZATION_MANAGER,
      ORGANIZATION_BILLING_MANAGER,
      ORGANIZATION_USER
    ].freeze

    SPACE_ROLES = [
      SPACE_AUDITOR,
      SPACE_MANAGER,
      SPACE_DEVELOPER,
      SPACE_SUPPORTER
    ].freeze

    ALL_ROLES = ORGANIZATION_ROLES + SPACE_ROLES
  end
end
