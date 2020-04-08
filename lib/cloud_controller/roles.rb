require 'set'

module VCAP::CloudController
  class Roles
    CLOUD_CONTROLLER_ADMIN_SCOPE = 'cloud_controller.admin'.freeze
    CLOUD_CONTROLLER_ADMIN_READ_ONLY_SCOPE = 'cloud_controller.admin_read_only'.freeze
    CLOUD_CONTROLLER_GLOBAL_AUDITOR = 'cloud_controller.global_auditor'.freeze
    CLOUD_CONTROLLER_BUILD_STATE_UPDATER = 'cloud_controller.update_build_state'.freeze

    ORG_ROLE_NAMES = [:user, :manager, :billing_manager, :auditor].freeze
    SPACE_ROLE_NAMES = [:manager, :developer, :auditor].freeze

    def initialize(token=nil)
      @scopes = Set.new(token && token['scope'])
    end

    def admin?
      @scopes.include?(CLOUD_CONTROLLER_ADMIN_SCOPE)
    end

    def admin_read_only?
      @scopes.include?(CLOUD_CONTROLLER_ADMIN_READ_ONLY_SCOPE)
    end

    def global_auditor?
      @scopes.include?(CLOUD_CONTROLLER_GLOBAL_AUDITOR)
    end

    def admin=(flag)
      @scopes.send(flag ? :add : :delete, CLOUD_CONTROLLER_ADMIN_SCOPE)
    end

    def build_state_updater?
      @scopes.include?(CLOUD_CONTROLLER_BUILD_STATE_UPDATER)
    end

    def none?
      @scopes.empty?
    end

    def present?
      @scopes.any?
    end
  end
end
