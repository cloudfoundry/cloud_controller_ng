# Copyright (c) 2009-2012 VMware, Inc.

require "cloud_controller/legacy_api/legacy_api_base"

module VCAP::CloudController
  class LegacyServiceLifecycle < LegacyApiBase
    attr_accessor :service_instance

    def job_info(gateway_name, job_id)
      service_instance.job_info(job_id)
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

    def create_serialized_url(gateway_name, snapshot_id)
      service_instance.create_serialized_url(snapshot_id)
    end

    def read_serialized_url(gateway_name, snapshot_id)
      service_instance.serialized_url(snapshot_id)
    end

    def get_upload_url(gateway_name)
      #TODO: switch upload url returns to point to sds
      "#{@config[:external_domain]}/services/v1/configurations/#{gateway_name}/serialized/data"
    end

    def import_from_url(gateway_name)
      service_instance.import_from_url(VCAP::Services::Api::SerializedURL.decode(body))
    end

    def import_from_data(gateway_name)
      file_path = data_file_path

      begin
        # Check the service and user's permission
        upload_token = config[:service_lifecycle][:upload_token]

        # Check the size of the uploaded file
        max_upload_size_mb = config[:service_lifecycle][:max_upload_size]
        max_upload_size = max_upload_size_mb * 1024 * 1024
        unless File.size(file_path) < max_upload_size
          raise BadQueryParameter, "data_file too large"
        end

        # Select a serialization data server
        active_sds = config[:service_lifecycle][:serialization_data_server]
        if active_sds.empty?
          raise SDSNotAvailable
        end
        upload_url = active_sds.sample

        req = {
          :upload_url => upload_url,
          :upload_token => upload_token,
          :data_file_path => data_file_path,
          :upload_timeout => config[:service_lifecycle][:upload_timeout],
        }
        logger.debug("import_from_data - request is #{req.inspect}")

        serialized_url = service_instance.import_from_data(req)
        service_instance.import_from_url(serialized_url)
      ensure
        FileUtils.rm_rf(file_path)
      end
    end

    def data_file_path
      path = nil
      if config[:nginx][:use_nginx]
        path = params.fetch("data_file_path")
        raise BadQueryParameter, "data_file_path" unless path && File.exist?(path)
      else
        file = params.fetch("data_file")
        if file && file.path && File.exist?(file.path)
          path = file.path
        else
          raise BadQueryParameter, "data_file"
        end
      end
      path
    end

    def dispatch(op, gateway_name, *args)
      # FIXME: should really be unauthenticated
      raise NotAuthorized unless user
      @service_instance = Models::ServiceInstance[
        :gateway_name => gateway_name,
        :space => default_space,
      ]
      raise ServiceInstanceNotFound, gateway_name unless service_instance
      json_message = super
      # maybe this .encode fits better in the methods so that it's more explicit
      json_message.encode
    rescue VCAP::Services::Api::ServiceGatewayClient::NotFoundResponse
      logger.debug("service instance not found while performing #{op}: #{gateway_name}")
      raise SnapshotNotFound, gateway_name
    rescue VCAP::Services::Api::ServiceGatewayClient::GatewayInternalResponse => e
      logger.error("service gateway error while performing #{op}: #{e}")
      raise ServiceGatewayError, e
    rescue VCAP::Services::Api::ServiceGatewayClient::ErrorResponse => e
      if e.status == 501
        logger.warn("We are running a service gateway that doesn't support lifecycle api: op: #{op}, error: #{e}")
        # make sure we pass on the 501 instead of a generic 500
        raise ServiceNotImplemented
      else
        logger.error("service gateway client error while performing #{op}: #{e}")
        raise ServerError
      end
    end

    get    "/services/v1/configurations/:gateway_name/jobs/:job_id",            :job_info

    post   "/services/v1/configurations/:gateway_name/snapshots",               :create
    get    "/services/v1/configurations/:gateway_name/snapshots",               :enumerate
    get    "/services/v1/configurations/:gateway_name/snapshots/:snapshot_id",  :read
    put    "/services/v1/configurations/:gateway_name/snapshots/:snapshot_id",  :rollback
    delete "/services/v1/configurations/:gateway_name/snapshots/:snapshot_id",  :delete

    post   "/services/v1/configurations/:gateway_name/serialized/url/snapshots/:snapshot_id", :create_serialized_url
    get    "/services/v1/configurations/:gateway_name/serialized/url/snapshots/:snapshot_id", :read_serialized_url

    put    "/services/v1/configurations/:gateway_name/serialized/url",  :import_from_url
    put    "/services/v1/configurations/:gateway_name/serialized/data", :import_from_data

    post   "/services/v1/configurations/:gateway_name/serialized/uploads", :get_upload_url
  end
end
