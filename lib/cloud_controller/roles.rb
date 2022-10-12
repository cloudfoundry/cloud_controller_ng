require 'set'

module VCAP::CloudController
  class Roles
    CLOUD_CONTROLLER_ADMIN_SCOPE = 'cloud_controller.admin'.freeze
    CLOUD_CONTROLLER_ADMIN_READ_ONLY_SCOPE = 'cloud_controller.admin_read_only'.freeze
    CLOUD_CONTROLLER_GLOBAL_AUDITOR = 'cloud_controller.global_auditor'.freeze
    CLOUD_CONTROLLER_BUILD_STATE_UPDATER = 'cloud_controller.update_build_state'.freeze
    CLOUD_CONTROLLER_READER_SCOPE = 'cloud_controller.read'.freeze
    CLOUD_CONTROLLER_WRITER_SCOPE = 'cloud_controller.write'.freeze
    CLOUD_CONTROLLER_SERVICE_PERMISSIONS_READER = 'cloud_controller_service_permissions.read'.freeze
    CLOUD_CONTROLLER_V2_RATE_LIMIT_EXEMPTION_SCOPE = 'cloud_controller.v2_api_rate_limit_exempt'.freeze

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

    def cloud_controller_reader?
      @scopes.include?(CLOUD_CONTROLLER_READER_SCOPE)
    end

    def cloud_controller_writer?
      @scopes.include?(CLOUD_CONTROLLER_WRITER_SCOPE)
    end

    def cloud_controller_service_permissions_reader?
      @scopes.include?(CLOUD_CONTROLLER_SERVICE_PERMISSIONS_READER)
    end

    def admin=(flag)
      @scopes.send(flag ? :add : :delete, CLOUD_CONTROLLER_ADMIN_SCOPE)
    end

    def build_state_updater?
      @scopes.include?(CLOUD_CONTROLLER_BUILD_STATE_UPDATER)
    end

    def v2_rate_limit_exempted?
      @scopes.include?(CLOUD_CONTROLLER_V2_RATE_LIMIT_EXEMPTION_SCOPE)
    end

    def none?
      @scopes.empty?
    end

    def present?
      @scopes.any?
    end
  end
end
