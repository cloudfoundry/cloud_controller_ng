require "cloud_controller/upload_handler"
require "presenters/api/job_presenter"

module VCAP::CloudController
  class AppBitsController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    def upload(guid)
      app = find_guid_and_validate_access(:update, guid)

      raise Errors::AppBitsUploadInvalid, "missing :resources" unless params["resources"]

      uploaded_zip_of_files_not_in_blobstore_path = CloudController::DependencyLocator.instance.upload_handler.uploaded_file(params, "application")
      app_bits_packer_job = AppBitsPackerJob.new(guid, uploaded_zip_of_files_not_in_blobstore_path, json_param("resources"))

      if async?
        job = Delayed::Job.enqueue(app_bits_packer_job, queue: LocalQueue.new(config))
        [HTTP::CREATED, JobPresenter.new(job).to_json]
      else
        app_bits_packer_job.perform
        [HTTP::CREATED, "{}"]
      end
    rescue VCAP::CloudController::Errors::AppBitsUploadInvalid, VCAP::CloudController::Errors::AppPackageInvalid
      app.mark_as_failed_to_stage
      raise
    end

    def download(guid)
      find_guid_and_validate_access(:read, guid)
      blobstore = CloudController::DependencyLocator.instance.package_blobstore
      package_uri = blobstore.download_uri(guid)

      logger.debug "guid: #{guid} package_uri: #{package_uri}"

      if package_uri.nil?
        Loggregator.emit_error(guid, "Could not find package for #{guid}")
        logger.error "could not find package for #{guid}"
        raise Errors::AppPackageNotFound.new(guid)
      end

      if blobstore.local?
        if config[:nginx][:use_nginx]
          return [200, { "X-Accel-Redirect" => "#{package_uri}" }, ""]
        else
          return send_file package_path, :filename => File.basename("#{path}.zip")
        end
      else
        return [HTTP::FOUND, {"Location" => package_uri}, nil]
      end
    end

    put "#{path_guid}/bits", :upload
    get "#{path_guid}/download", :download

    private

    def json_param(name)
      raw = params[name]
      Yajl::Parser.parse(raw)
    rescue Yajl::ParseError
      raise Errors::AppBitsUploadInvalid.new("invalid :#{name}")
    end
  end
end
