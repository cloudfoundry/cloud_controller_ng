# Copyright (c) 2009-2012 VMware, Inc.
require "services/api"

module VCAP::CloudController::Models
  class ServiceInstance < Sequel::Model
    class InvalidServiceBinding < StandardError; end

    many_to_one :service_plan
    many_to_one :space
    one_to_many :service_bindings, :before_add => :validate_service_binding

    default_order_by  :id

    export_attributes :name, :credentials, :service_plan_guid,
                      :space_guid, :gateway_data

    import_attributes :name, :service_plan_guid,
                      :space_guid, :gateway_data

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :space
      validates_presence :service_plan
      validates_unique   [:space_id, :name]
    end

    def before_create
      super
      provision_on_gateway
    end

    def after_destroy
      super
      deprovision_on_gateway
    end

    def after_commit
      @provisioned_on_gateway_for_plan = nil
      super
    end

    def after_rollback
      deprovision_on_gateway if @provisioned_on_gateway_for_plan
      super
    end

    def validate_service_binding(service_binding)
      if service_binding && service_binding.app.space != space
        # FIXME: unlike most other validations, this is *NOT* being enforced
        # by the underlying db.
        raise InvalidServiceBinding.new(service_binding.id)
      end
    end

    def credentials=(val)
      str = Yajl::Encoder.encode(val)
      super(str)
    end

    def credentials
      val = super
      val = Yajl::Parser.parse(val) if val
      val
    end

    def gateway_data=(val)
      str = Yajl::Encoder.encode(val)
      super(str)
    end

    def gateway_data
      val = super
      val = Yajl::Parser.parse(val) if val
      val
    end

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(
        :space => user.spaces_dataset)
    end

    def requester
      VCAP::Services::Api::SynchronousHttpRequest
    end

    def service_gateway_client(plan = service_plan)
      # This should only happen during unit testing if we are saving without
      # validations to test db constraints
      return unless plan

      # TODO: this shouldn't be allowed to be nil.  There is a story filed to
      # address this.
      unless plan.service.service_auth_token
        logger.error "no auth token found for #{service_plan.service.inspect}"
        return
      end

      VCAP::Services::Api::ServiceGatewayClient.new(
        plan.service.url,
        plan.service.service_auth_token.token,
        plan.service.timeout,
        :requester => requester
      )
    end

    def provision_on_gateway
      client = service_gateway_client

      # TODO: see service_gateway_client
      unless client
        self.gateway_name = nil
        self.gateway_data = nil
        self.credentials  = {}
        return
      end

      logger.debug "provisioning service for instance #{guid}"

      gw_attrs = client.provision(
        # TODO: we shouldn't still be using this compound label
        :label => "#{service_plan.service.label}-#{service_plan.service.version}",
        :name  => name,
        :email => "todo@todo.com", # TODO
        :plan  => service_plan.name,
        :plan_option => {}, # TODO: remove this
        :version => service_plan.service.version
      )

      logger.debug "provision response for instance #{guid} #{gw_attrs.inspect}"

      self.gateway_name = gw_attrs.service_id
      self.gateway_data = gw_attrs.configuration
      self.credentials  = gw_attrs.credentials

      @provisioned_on_gateway_for_plan = service_plan
    end

    def deprovision_on_gateway
      plan = @provisioned_on_gateway_for_plan || service_plan
      client = service_gateway_client(plan)
      return unless client # TODO: see service_gateway_client
      @provisioned_on_gateway_for_plan = nil
      client.unprovision(:service_id => gateway_name)
    rescue => e
      logger.error "deprovision failed #{e}"
    end

    def create_snapshot
      client = service_gateway_client
      client.create_snapshot(:service_id => gateway_name)
    end

    def enum_snapshots
      client = service_gateway_client
      client.enum_snapshots(:service_id => gateway_name)
    end

    def snapshot_details(sid)
      client = service_gateway_client
      client.snapshot_details(:service_id => gateway_name, :snapshot_id => sid)
    end

    def rollback_snapshot(sid)
      client = service_gateway_client
      client.rollback_snapshot(:service_id => gateway_name, :snapshot_id => sid)
    end

    def delete_snapshot(sid)
      client = service_gateway_client
      client.delete_snapshot(:service_id => gateway_name, :snapshot_id => sid)
    end

    def serialized_url(sid)
      client = service_gateway_client
      client.serialized_url(:service_id => gateway_name, :snapshot_id => sid)
    end

    def create_serialized_url(sid)
      client = service_gateway_client
      client.create_serialized_url(:service_id => gateway_name, :snapshot_id => sid)
    end

    def import_from_url(req)
      client = service_gateway_client
      client.import_from_url(:service_id => gateway_name, :msg => req)
    end

    def job_info(job_id)
      client = service_gateway_client
      client.job_info(:service_id => gateway_name, :job_id => job_id)
    end

    def logger
      @logger ||= Steno.logger("cc.models.service_instance")
    end
  end
end
