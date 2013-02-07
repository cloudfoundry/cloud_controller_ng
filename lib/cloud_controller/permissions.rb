# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController
  module Permissions
    class << self
      # Given a user, return the array of permissions granted to the user.
      #
      # @param [Object] obj The object for which to lookup permissions
      #
      # @param [Models::User] user The user for which to lookup permissions.
      #
      # @return [Array] Array of permissions granted to the user.
      def permissions_for(obj, user, roles)
        permissions.select { |perm| perm.granted_to?(obj, user, roles) }
      end

      # Used by permission implementations to register themselves as a valid
      # permission.
      #
      # @param [Permission] permission The permssion to register.
      def register(permission)
        permissions << permission
      end

      private

      def permissions
        @permissions ||= []
      end
    end
  end
end

require "cloud_controller/permissions/org_permissions"
require "cloud_controller/permissions/space_permissions"

Dir[File.expand_path("../permissions/*", __FILE__)].each do |file|
  require file
end
