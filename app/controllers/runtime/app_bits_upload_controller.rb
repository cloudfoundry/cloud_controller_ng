require "presenters/api/job_presenter"

module VCAP::CloudController
  class AppBitsUploadController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    def check_authentication(op)
      auth = env["HTTP_AUTHORIZATION"]
      grace_period = config.fetch(:app_bits_upload_grace_period_in_seconds, 0)
      relaxed_token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa], grace_period)
      VCAP::CloudController::Security::SecurityContextConfigurer.new(relaxed_token_decoder).configure(auth)
      super
    end

    put "#{path_guid}/bits", :upload
    def upload(guid)
      app = find_guid_and_validate_access(:upload, guid)

      raise Errors::ApiError.new_from_details("AppBitsUploadInvalid", "missing :resources") unless params["resources"]

      uploaded_zip_of_files_not_in_blobstore_path = CloudController::DependencyLocator.instance.upload_handler.uploaded_file(params, "application")
      app_bits_packer_job = Jobs::Runtime::AppBitsPacker.new(guid, uploaded_zip_of_files_not_in_blobstore_path, json_param("resources"))

      if async?
        job = Jobs::Enqueuer.new(app_bits_packer_job, queue: Jobs::LocalQueue.new(config)).enqueue()
        [HTTP::CREATED, JobPresenter.new(job).to_json]
      else
        app_bits_packer_job.perform
        [HTTP::CREATED, "{}"]
      end
    rescue VCAP::CloudController::Errors::ApiError => e

      if e.name == "AppBitsUploadInvalid" || e.name == "AppPackageInvalid"
        app.mark_as_failed_to_stage
      end
      raise
    end

    private

    def json_param(name)
      raw = params[name]
      MultiJson.load(raw)
    rescue MultiJson::ParseError
      raise Errors::ApiError.new_from_details("AppBitsUploadInvalid", "invalid :#{name}")
    end
  end
end
