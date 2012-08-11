# Copyright (c) 2009-2012 VMware, Inc.

require "cloud_controller/legacy_api/legacy_api_base"

module VCAP::CloudController
  class LegacyServiceLifecycle < LegacyApiBase
    attr_accessor :service_instance

    def job_info(gateway_name, job_id)
    end

    def create(gateway_name)
      service_instance.create_snapshot
    end

    def enumerate(gateway_name)
      service_instance.enum_snapshots
    end

    def read(gateway_name, snapshot_id)
      service_instance.snapshot_details(snapshot_id)
    end

    def rollback(gateway_name, snapshot_id)
      service_instance.rollback_snapshot(snapshot_id)
    end

    def delete(gateway_name, snapshot_id)
      service_instance.delete_snapshot(snapshot_id)
    end

    def dispatch(op, gateway_name, *args)
      raise NotAuthorized unless user
      @service_instance = Models::ServiceInstance[
        :gateway_name => gateway_name,
        :space => default_space,
      ]
      raise ServiceInstanceNotFound, gateway_name unless service_instance
      json_message = super
      json_message.encode
    rescue VCAP::Services::Api::ServiceGatewayClient::NotFoundResponse
      raise SnapshotNotFound, gateway_name
    end

    get    "/services/v1/configurations/:gateway_name/jobs/:job_id",            :job_info

    post   "/services/v1/configurations/:gateway_name/snapshots",               :create
    get    "/services/v1/configurations/:gateway_name/snapshots",               :enumerate
    get    "/services/v1/configurations/:gateway_name/snapshots/:snapshot_id",  :read
    put    "/services/v1/configurations/:gateway_name/snapshots/:snapshot_id",  :rollback
    delete "/services/v1/configurations/:gateway_name/snapshots/:snapshot_id",  :delete

    post   "/services/v1/configurations/:gateway_name/serialized/url/snapshots/:snapshot_id", :create_serialized_url
    get    "/services/v1/configurations/:gateway_name/serialized/url/snapshots/:snapshot_id", :serialized_url

    put    "/services/v1/configurations/:gateway_name/serialized/url",  :import_from_url
    put    "/services/v1/configurations/:gateway_name/serialized/data", :import_from_data
  end
end
