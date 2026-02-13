module VCAP::CloudController
  module Repositories
    class EventTypes
      class EventTypesError < StandardError
      end

      AUDIT_EVENTS = [
        APP_CREATE = 'audit.app.create'.freeze,
        APP_UPDATE = 'audit.app.update'.freeze,
        APP_DELETE_REQUEST = 'audit.app.delete-request'.freeze,
        APP_START = 'audit.app.start'.freeze,
        APP_RESTART = 'audit.app.restart'.freeze,
        APP_RESTAGE = 'audit.app.restage'.freeze,
        APP_STOP = 'audit.app.stop'.freeze,

        APP_PACKAGE_CREATE = 'audit.app.package.create'.freeze,
        APP_PACKAGE_UPLOAD = 'audit.app.package.upload'.freeze,
        APP_PACKAGE_DOWNLOAD = 'audit.app.package.download'.freeze,
        APP_PACKAGE_DELETE = 'audit.app.package.delete'.freeze,

        APP_PROCESS_CREATE = 'audit.app.process.create'.freeze,
        APP_PROCESS_UPDATE = 'audit.app.process.update'.freeze,
        APP_PROCESS_DELETE = 'audit.app.process.delete'.freeze,
        APP_PROCESS_RESCHEDULING = 'audit.app.process.rescheduling'.freeze,
        APP_PROCESS_CRASH = 'audit.app.process.crash'.freeze,
        APP_PROCESS_TERMINATE_INSTANCE = 'audit.app.process.terminate_instance'.freeze,
        APP_PROCESS_SCALE = 'audit.app.process.scale'.freeze,
        APP_PROCESS_READY = 'audit.app.process.ready'.freeze,
        APP_PROCESS_NOT_READY = 'audit.app.process.not-ready'.freeze,

        APP_DROPLET_CREATE = 'audit.app.droplet.create'.freeze,
        APP_DROPLET_UPLOAD = 'audit.app.droplet.upload'.freeze,
        APP_DROPLET_DOWNLOAD = 'audit.app.droplet.download'.freeze,
        APP_DROPLET_DELETE = 'audit.app.droplet.delete'.freeze,
        APP_DROPLET_MAPPED = 'audit.app.droplet.mapped'.freeze,

        APP_TASK_CREATE = 'audit.app.task.create'.freeze,
        APP_TASK_CANCEL = 'audit.app.task.cancel'.freeze,

        APP_MAP_ROUTE = 'audit.app.map-route'.freeze,
        APP_UNMAP_ROUTE = 'audit.app.unmap-route'.freeze,

        APP_BUILD_CREATE = 'audit.app.build.create'.freeze,
        APP_BUILD_STAGED = 'audit.app.build.staged'.freeze,
        APP_BUILD_FAILED = 'audit.app.build.failed'.freeze,
        APP_ENVIRONMENT_SHOW = 'audit.app.environment.show'.freeze,
        APP_ENVIRONMENT_VARIABLE_SHOW = 'audit.app.environment_variables.show'.freeze,
        APP_REVISION_CREATE = 'audit.app.revision.create'.freeze,
        APP_REVISION_ENV_VARS_SHOW = 'audit.app.revision.environment_variables.show'.freeze,
        APP_DEPLOYMENT_CANCEL = 'audit.app.deployment.cancel'.freeze,
        APP_DEPLOYMENT_CREATE = 'audit.app.deployment.create'.freeze,
        APP_DEPLOYMENT_CONTINUE = 'audit.app.deployment.continue'.freeze,
        APP_COPY_BITS = 'audit.app.copy-bits'.freeze,
        APP_UPLOAD_BITS = 'audit.app.upload-bits'.freeze,
        APP_APPLY_MANIFEST = 'audit.app.apply_manifest'.freeze,
        APP_SSH_AUTHORIZED = 'audit.app.ssh-authorized'.freeze,
        APP_SSH_UNAUTHORIZED = 'audit.app.ssh-unauthorized'.freeze,

        BUILDPACK_CREATE = 'audit.buildpack.create'.freeze,
        BUILDPACK_UPDATE = 'audit.buildpack.update'.freeze,
        BUILDPACK_DELETE = 'audit.buildpack.delete'.freeze,
        BUILDPACK_UPLOAD = 'audit.buildpack.upload'.freeze,

        SERVICE_CREATE = 'audit.service.create'.freeze,
        SERVICE_UPDATE = 'audit.service.update'.freeze,
        SERVICE_DELETE = 'audit.service.delete'.freeze,

        SERVICE_BROKER_CREATE = 'audit.service_broker.create'.freeze,
        SERVICE_BROKER_UPDATE = 'audit.service_broker.update'.freeze,
        SERVICE_BROKER_DELETE = 'audit.service_broker.delete'.freeze,

        SERVICE_PLAN_CREATE = 'audit.service_plan.create'.freeze,
        SERVICE_PLAN_UPDATE = 'audit.service_plan.update'.freeze,
        SERVICE_PLAN_DELETE = 'audit.service_plan.delete'.freeze,

        SERVICE_INSTANCE_CREATE = 'audit.service_instance.create'.freeze,
        SERVICE_INSTANCE_UPDATE = 'audit.service_instance.update'.freeze,
        SERVICE_INSTANCE_DELETE = 'audit.service_instance.delete'.freeze,
        SERVICE_INSTANCE_START_CREATE = 'audit.service_instance.start_create'.freeze,
        SERVICE_INSTANCE_START_UPDATE = 'audit.service_instance.start_update'.freeze,
        SERVICE_INSTANCE_START_DELETE = 'audit.service_instance.start_delete'.freeze,
        SERVICE_INSTANCE_BIND_ROUTE = 'audit.service_instance.bind_route'.freeze,
        SERVICE_INSTANCE_UNBIND_ROUTE = 'audit.service_instance.unbind_route'.freeze,
        SERVICE_INSTANCE_SHARE = 'audit.service_instance.share'.freeze,
        SERVICE_INSTANCE_UNSHARE = 'audit.service_instance.unshare'.freeze,
        SERVICE_INSTANCE_PURGE = 'audit.service_instance.purge'.freeze,
        SERVICE_INSTANCE_SHOW = 'audit.service_instance.show'.freeze,

        SERVICE_BINDING_CREATE = 'audit.service_binding.create'.freeze,
        SERVICE_BINDING_UPDATE = 'audit.service_binding.update'.freeze,
        SERVICE_BINDING_DELETE = 'audit.service_binding.delete'.freeze,
        SERVICE_BINDING_START_CREATE = 'audit.service_binding.start_create'.freeze,
        SERVICE_BINDING_START_DELETE = 'audit.service_binding.start_delete'.freeze,
        SERVICE_BINDING_SHOW = 'audit.service_binding.show'.freeze,

        SERVICE_KEY_CREATE = 'audit.service_key.create'.freeze,
        SERVICE_KEY_UPDATE = 'audit.service_key.update'.freeze,
        SERVICE_KEY_DELETE = 'audit.service_key.delete'.freeze,
        SERVICE_KEY_START_CREATE = 'audit.service_key.start_create'.freeze,
        SERVICE_KEY_START_DELETE = 'audit.service_key.start_delete'.freeze,
        SERVICE_KEY_SHOW = 'audit.service_key.show'.freeze,

        SERVICE_PLAN_VISIBILITY_CREATE = 'audit.service_plan_visibility.create'.freeze,
        SERVICE_PLAN_VISIBILITY_UPDATE = 'audit.service_plan_visibility.update'.freeze,
        SERVICE_PLAN_VISIBILITY_DELETE = 'audit.service_plan_visibility.delete'.freeze,

        SERVICE_ROUTE_BINDING_CREATE = 'audit.service_route_binding.create'.freeze,
        SERVICE_ROUTE_BINDING_UPDATE = 'audit.service_route_binding.update'.freeze,
        SERVICE_ROUTE_BINDING_DELETE = 'audit.service_route_binding.delete'.freeze,
        SERVICE_ROUTE_BINDING_START_CREATE =  'audit.service_route_binding.start_create'.freeze,
        SERVICE_ROUTE_BINDING_START_DELETE =  'audit.service_route_binding.start_delete'.freeze,

        USER_PROVIDED_SERVICE_INSTANCE_CREATE = 'audit.user_provided_service_instance.create'.freeze,
        USER_PROVIDED_SERVICE_INSTANCE_UPDATE = 'audit.user_provided_service_instance.update'.freeze,
        USER_PROVIDED_SERVICE_INSTANCE_DELETE = 'audit.user_provided_service_instance.delete'.freeze,
        USER_PROVIDED_SERVICE_INSTANCE_SHOW = 'audit.user_provided_service_instance.show'.freeze,

        ROUTE_CREATE = 'audit.route.create'.freeze,
        ROUTE_UPDATE = 'audit.route.update'.freeze,
        ROUTE_DELETE_REQUEST = 'audit.route.delete-request'.freeze,
        ROUTE_SHARE = 'audit.route.share'.freeze,
        ROUTE_UNSHARE = 'audit.route.unshare'.freeze,
        ROUTE_TRANSFER_OWNER = 'audit.route.transfer-owner'.freeze,

        ORGANIZATION_CREATE = 'audit.organization.create'.freeze,
        ORGANIZATION_UPDATE = 'audit.organization.update'.freeze,
        ORGANIZATION_DELETE_REQUEST = 'audit.organization.delete-request'.freeze,

        ORGANIZATION_QUOTA_CREATE = 'audit.organization_quota.create'.freeze,
        ORGANIZATION_QUOTA_UPDATE = 'audit.organization_quota.update'.freeze,
        ORGANIZATION_QUOTA_DELETE = 'audit.organization_quota.delete'.freeze,
        ORGANIZATION_QUOTA_APPLY = 'audit.organization_quota.apply'.freeze,

        SPACE_CREATE = 'audit.space.create'.freeze,
        SPACE_UPDATE = 'audit.space.update'.freeze,
        SPACE_DELETE_REQUEST = 'audit.space.delete-request'.freeze,

        SPACE_QUOTA_CREATE = 'audit.space_quota.create'.freeze,
        SPACE_QUOTA_UPDATE = 'audit.space_quota.update'.freeze,
        SPACE_QUOTA_DELETE = 'audit.space_quota.delete'.freeze,
        SPACE_QUOTA_APPLY = 'audit.space_quota.apply'.freeze,
        SPACE_QUOTA_REMOVE = 'audit.space_quota.remove'.freeze,

        STACK_CREATE = 'audit.stack.create'.freeze,
        STACK_UPDATE = 'audit.stack.update'.freeze,
        STACK_DELETE = 'audit.stack.delete'.freeze,

        USER_SPACE_AUDITOR_ADD = 'audit.user.space_auditor_add'.freeze,
        USER_SPACE_AUDITOR_REMOVE = 'audit.user.space_auditor_remove'.freeze,
        USER_SPACE_SUPPORTER_ADD = 'audit.user.space_supporter_add'.freeze,
        USER_SPACE_SUPPORTER_REMOVE = 'audit.user.space_supporter_remove'.freeze,
        USER_SPACE_DEVELOPER_ADD = 'audit.user.space_developer_add'.freeze,
        USER_SPACE_DEVELOPER_REMOVE = 'audit.user.space_developer_remove'.freeze,
        USER_SPACE_MANAGER_ADD = 'audit.user.space_manager_add'.freeze,
        USER_SPACE_MANAGER_REMOVE = 'audit.user.space_manager_remove'.freeze,

        SERVICE_DASHBOARD_CLIENT_CREATE = 'audit.service_dashboard_client.create'.freeze,
        SERVICE_DASHBOARD_CLIENT_DELETE = 'audit.service_dashboard_client.delete'.freeze,

        USER_ORGANIZATION_USER_ADD = 'audit.user.organization_user_add'.freeze,
        USER_ORGANIZATION_USER_REMOVE = 'audit.user.organization_user_remove'.freeze,
        USER_ORGANIZATION_AUDITOR_ADD = 'audit.user.organization_auditor_add'.freeze,
        USER_ORGANIZATION_AUDITOR_REMOVE = 'audit.user.organization_auditor_remove'.freeze,
        USER_ORGANIZATION_BILLING_MANAGER_ADD = 'audit.user.organization_billing_manager_add'.freeze,
        USER_ORGANIZATION_BILLING_MANAGER_REMOVE = 'audit.user.organization_billing_manager_remove'.freeze,
        USER_ORGANIZATION_MANAGER_ADD = 'audit.user.organization_manager_add'.freeze,
        USER_ORGANIZATION_MANAGER_REMOVE = 'audit.user.organization_manager_remove'.freeze
      ].freeze

      SPECIAL_EVENTS = [
        APP_CRASH = 'app.crash'.freeze,
        BLOB_REMOVE_ORPHAN = 'blob.remove_orphan'.freeze
      ].freeze

      ALL_EVENT_TYPES = [
        AUDIT_EVENTS,
        SPECIAL_EVENTS
      ].freeze

      USER_SPACE_EVENTS = [
        USER_SPACE_AUDITOR_ADD,
        USER_SPACE_AUDITOR_REMOVE,
        USER_SPACE_SUPPORTER_ADD,
        USER_SPACE_SUPPORTER_REMOVE,
        USER_SPACE_DEVELOPER_ADD,
        USER_SPACE_DEVELOPER_REMOVE,
        USER_SPACE_MANAGER_ADD,
        USER_SPACE_MANAGER_REMOVE
      ].freeze

      USER_ORGANIZATION_EVENTS = [
        USER_ORGANIZATION_USER_ADD,
        USER_ORGANIZATION_USER_REMOVE,
        USER_ORGANIZATION_AUDITOR_ADD,
        USER_ORGANIZATION_AUDITOR_REMOVE,
        USER_ORGANIZATION_BILLING_MANAGER_ADD,
        USER_ORGANIZATION_BILLING_MANAGER_REMOVE,
        USER_ORGANIZATION_MANAGER_ADD,
        USER_ORGANIZATION_MANAGER_REMOVE
      ].freeze

      def self.get(event_type_str)
        event_type_str = event_type_str.upcase
        raise EventTypesError.new("Audit event type '#{event_type_str}' is invalid.") unless EventTypes.const_defined?(event_type_str)

        EventTypes.const_get(event_type_str)
      end
    end
  end
end
