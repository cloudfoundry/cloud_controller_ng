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

    import_attributes :name, :credentials, :service_plan_guid,
                      :space_guid, :gateway_data

    strip_attributes  :name

    def validate
      # we can't use validates_presence because it ends up using the
      # credentials method below and looks at the hash, which can be empty..
      # and that isn't the same thing as nil for us
      errors.add(:credentials, :presence) if credentials.nil?

      validates_presence :name
      validates_presence :space
      validates_presence :service_plan
      validates_unique   [:space_id, :name]
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

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(
        :space => user.spaces_dataset)
    end

    def requester
      VCAP::Services::Api::SynchronousHttpRequest
    end

    def service_gateway_client
      VCAP::Services::Api::ServiceGatewayClient.new(
        service_plan.service.url,
        service_plan.service.service_auth_token.token,
        service_plan.service.timeout,
        :requester => requester
      )
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

  end
end
