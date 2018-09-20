require 'perm'

module VCAP::CloudController
  module Perm
    class Client
      def self.build_from_config(config, file_opener)
        enabled = config.get(:perm, :enabled)

        hostname = ''
        port = 0
        timeout = 0
        trusted_cas = []

        if enabled
          hostname = config.get(:perm, :hostname)
          port = config.get(:perm, :port)
          ca_cert_path = config.get(:perm, :ca_cert_path)
          timeout = config.get(:perm, :timeout_in_milliseconds) / 1000.0
          trusted_cas << file_opener.open(ca_cert_path).read
        end

        self.new(hostname: hostname, port: port, enabled: enabled, trusted_cas: trusted_cas, logger_name: 'perm.client', timeout: timeout)
      end

      def initialize(hostname:, port:, enabled:, trusted_cas:, logger_name:, timeout:)
        @hostname = hostname
        @port = port
        @trusted_cas = trusted_cas
        @enabled = enabled
        @logger_name = logger_name
        @timeout = timeout
      end

      # When this object is passed across the boundary to DelayedJob it is serialized in the database
      # and then automatically rehydrated on the other side
      # This does not work in our case because
      # a) The gRPC connection is broken
      # b) The logger's Syslog logger cannot be serialized
      # Instead, provide a custom rehydrate method that returns a new object
      # and do this when performing the DelayedJob
      def rehydrate
        Client.new(hostname: hostname, port: port, enabled: enabled, trusted_cas: trusted_cas, logger_name: logger_name, timeout: timeout)
      end

      def create_org_role(role:, org_id:)
        create_role(org_role(role, org_id), [
          org_role_to_permission(role, org_id)
        ])
      end

      def delete_org_role(role:, org_id:)
        delete_role(org_role(role, org_id))
      end

      def assign_org_role(role:, org_id:, user_id:, issuer:)
        assign_role(role: org_role(role, org_id), user_id: user_id, issuer: issuer)
      end

      def unassign_org_role(role:, org_id:, user_id:, issuer:)
        unassign_role(role: org_role(role, org_id), user_id: user_id, issuer: issuer)
      end

      def create_space_role(role:, space_id:)
        create_role(space_role(role, space_id), [
          space_role_to_permission(role, space_id)
        ])
      end

      def delete_space_role(role:, space_id:)
        delete_role(space_role(role, space_id))
      end

      def assign_space_role(role:, space_id:, user_id:, issuer:)
        assign_role(role: space_role(role, space_id), user_id: user_id, issuer: issuer)
      end

      def unassign_space_role(role:, space_id:, user_id:, issuer:)
        unassign_role(role: space_role(role, space_id), user_id: user_id, issuer: issuer)
      end

      def unassign_roles(org_ids: [], space_ids: [], user_id:, issuer:)
        space_ids.each do |space_id|
          VCAP::CloudController::Roles::SPACE_ROLE_NAMES.each do |role|
            unassign_space_role(role: role, space_id: space_id, user_id: user_id, issuer: issuer)
          end
        end

        org_ids.each do |org_id|
          VCAP::CloudController::Roles::ORG_ROLE_NAMES.each do |role|
            unassign_org_role(role: role, org_id: org_id, user_id: user_id, issuer: issuer)
          end
        end
      end

      def has_any_permission?(permissions:, user_id:, issuer:)
        if enabled
          permissions.any? do |permission|
            has_permission?(action: permission[:action], resource: permission[:resource], issuer: issuer, user_id: user_id)
          end
        else
          false
        end
      end

      def has_permission?(action:, resource:, user_id:, issuer:)
        if enabled
          begin
            client.has_permission?(actor_id: user_id, namespace: issuer, action: action, resource: resource)
          rescue CloudFoundry::Perm::V1::Errors::BadStatus => e
            logger.error('has-permission?.bad-status',
                action: action, resource: resource, user_id: user_id, issuer: issuer,
                status: e.class.to_s, code: e.code, details: e.details, metadata: e.metadata)
            false
          rescue StandardError => e
            logger.error('has-permission?.failed',
              action: action, resource: resource, user_id: user_id, issuer: issuer,
              message: e.message)
            false
          end
        else
          false
        end
      end

      def list_unique_resource_patterns(user_id:, issuer:, actions:)
        if enabled
          begin
            actions.map do |action|
              list_resource_patterns_for_action(user_id: user_id, issuer: issuer, action: action)
            end.flatten.uniq
          rescue CloudFoundry::Perm::V1::Errors::BadStatus => e
            logger.error(
              'list-resource-patterns.bad-status',
              user_id: user_id,
              issuer: issuer,
              actions: actions,
              status: e.class.to_s,
              code: e.code,
              details: e.details,
              metadata: e.metadata
            )

            []
          rescue StandardError => e
            logger.error(
              'list-resource-patterns.failed',
              user_id: user_id,
              issuer: issuer,
              actions: actions,
              message: e.message,
              backtrace: e.backtrace
            )

            []
          end
        else
          []
        end
      end

      private

      attr_reader :hostname, :port, :enabled, :trusted_cas, :logger_name, :timeout

      def client
        @client ||= CloudFoundry::Perm::V1::Client.new(hostname: hostname, port: port, trusted_cas: trusted_cas, timeout: timeout)
      end

      def org_role(role, org_id)
        "org-#{role}-#{org_id}"
      end

      def space_role(role, space_id)
        "space-#{role}-#{space_id}"
      end

      def org_role_to_permission(role, org_id)
        CloudFoundry::Perm::V1::Models::Permission.new(
          action: "org.#{role}",
          resource_pattern: org_id.to_s
        )
      end

      def space_role_to_permission(role, space_id)
        CloudFoundry::Perm::V1::Models::Permission.new(
          action: "space.#{role}",
          resource_pattern: space_id.to_s
        )
      end

      def create_role(role, permissions=[])
        if enabled
          begin
            client.create_role(role_name: role, permissions: permissions)
          rescue CloudFoundry::Perm::V1::Errors::AlreadyExists
            logger.debug('create-role.role-already-exists', role: role)
          rescue CloudFoundry::Perm::V1::Errors::BadStatus => e
            logger.error('create-role.bad-status', role: role, status: e.class.to_s, code: e.code, details: e.details, metadata: e.metadata)
          rescue StandardError => e
            logger.error('create-role.failed', role: role, message: e.message)
          end
        end
      end

      def delete_role(role)
        if enabled
          begin
            client.delete_role(role)
          rescue CloudFoundry::Perm::V1::Errors::NotFound
            logger.debug('delete-role.role-does-not-exist', role: role)
          rescue CloudFoundry::Perm::V1::Errors::BadStatus => e
            logger.error('delete-role.bad-status', role: role, status: e.class.to_s, code: e.code, details: e.details, metadata: e.metadata)
          rescue StandardError => e
            logger.error('delete-role.failed', role: role, message: e.message)
          end
        end
      end

      def assign_role(role:, user_id:, issuer:)
        if enabled
          begin
            client.assign_role(role_name: role, actor_id: user_id, namespace: issuer)
          rescue CloudFoundry::Perm::V1::Errors::AlreadyExists
            logger.debug('assign-role.assignment-already-exists', role: role, user_id: user_id, issuer: issuer)
          rescue CloudFoundry::Perm::V1::Errors::NotFound
            logger.error('assign-role.role-does-not-exist', role: role, user_id: user_id, issuer: issuer)
          rescue CloudFoundry::Perm::V1::Errors::BadStatus => e
            logger.error('assign-role.bad-status', role: role, user_id: user_id, issuer: issuer, status: e.class.to_s, code: e.code, details: e.details, metadata: e.metadata)
          rescue StandardError => e
            logger.error('assign-role.failed', role: role, message: e.message)
          end
        end
      end

      def unassign_role(role:, user_id:, issuer:)
        if enabled
          begin
            client.unassign_role(role_name: role, actor_id: user_id, namespace: issuer)
          rescue CloudFoundry::Perm::V1::Errors::NotFound => e
            logger.error('unassign-role.resource-not-found', role: role, user_id: user_id, issuer: issuer, details: e.details, metadata: e.metadata)
          rescue CloudFoundry::Perm::V1::Errors::BadStatus => e
            logger.error('unassign-role.bad-status', role: role, user_id: user_id, issuer: issuer, status: e.class.to_s, code: e.code, details: e.details, metadata: e.metadata)
          rescue StandardError => e
            logger.error('unassign-role.failed', role: role, message: e.message)
          end
        end
      end

      def list_resource_patterns_for_action(user_id:, issuer:, action:)
        client.list_resource_patterns(actor_id: user_id, namespace: issuer, action: action)
      end

      # Can't be cached because the Syslog logger doesn't deserialize correctly for delayed jobs :(
      def logger
        Steno.logger(logger_name)
      end
    end
  end
end
