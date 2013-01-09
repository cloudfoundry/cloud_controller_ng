# Copyright (c) 2009-2013 VMware, Inc.

require 'set'

module VCAP::CloudController

  class Roles
    CLOUD_CONTROLLER_ADMIN_SCOPE = 'cloud_controller.admin'

    def initialize(token = nil)
      @scopes = Set.new(token && token['scope'])
    end

    def admin?
      @scopes.include?(CLOUD_CONTROLLER_ADMIN_SCOPE)
    end

    def admin=(flag)
      @scopes.send(flag ? :add : :delete, CLOUD_CONTROLLER_ADMIN_SCOPE)
    end

    def none?
      @scopes.size == 0
    end

    def present?
      @scopes.size > 0
    end

    def satisfies_relation(relation)
      # currently the only way to satisfy any relation
      # is with the admin role
      admin?
    end
  end
end