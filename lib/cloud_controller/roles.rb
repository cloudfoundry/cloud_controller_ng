require 'set'

module VCAP::CloudController
  class Roles
    CLOUD_CONTROLLER_ADMIN_SCOPE = 'cloud_controller.admin'.freeze
    CLOUD_CONTROLLER_ADMIN_READ_ONLY_SCOPE = 'cloud_controller.admin_read_only'.freeze

    def initialize(token=nil)
      @scopes = Set.new(token && token['scope'])
    end

    def admin?
      @scopes.include?(CLOUD_CONTROLLER_ADMIN_SCOPE)
    end

    def admin_read_only?
      @scopes.include?(CLOUD_CONTROLLER_ADMIN_READ_ONLY_SCOPE)
    end

    def admin=(flag)
      @scopes.send(flag ? :add : :delete, CLOUD_CONTROLLER_ADMIN_SCOPE)
    end

    def none?
      @scopes.empty?
    end

    def present?
      @scopes.any?
    end
  end
end
