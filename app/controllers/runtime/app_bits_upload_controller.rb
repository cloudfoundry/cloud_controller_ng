require 'presenters/api/job_presenter'

module VCAP::CloudController
  class AppBitsUploadController < RestController::ModelController
    def self.dependencies
      [:app_event_repository]
    end

    path_base 'apps'
    model_class_name :App

    def inject_dependencies(dependencies)
      super
      @app_event_repository = dependencies.fetch(:app_event_repository)
    end

    def check_authentication(op)
      auth = env['HTTP_AUTHORIZATION']
      grace_period = config.fetch(:app_bits_upload_grace_period_in_seconds, 0)
      relaxed_token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa], grace_period)
      VCAP::CloudController::Security::SecurityContextConfigurer.new(relaxed_token_decoder).configure(auth)
      super
    end

    put "#{path_guid}/bits", :upload
    def upload(guid)
      app = find_guid_and_validate_access(:upload, guid)

      raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'missing :resources') unless params['resources']
      uploaded_zip_of_files_not_in_blobstore_path = CloudController::DependencyLocator.instance.upload_handler.uploaded_file(params, 'application')

      app_bits_packer_job = packer_class.new(guid, uploaded_zip_of_files_not_in_blobstore_path, json_param('resources'))

      if async?
        job = Jobs::Enqueuer.new(app_bits_packer_job, queue: Jobs::LocalQueue.new(config)).enqueue
        [HTTP::CREATED, JobPresenter.new(job).to_json]
      else
        app_bits_packer_job.perform
        [HTTP::CREATED, '{}']
      end
    rescue CloudController::Errors::ApiError => e
      if e.name == 'AppBitsUploadInvalid' || e.name == 'AppPackageInvalid' || e.name == 'AppResourcesFileModeInvalid' || e.name == 'AppResourcesFilePathInvalid'
        app.mark_as_failed_to_stage
      end
      raise
    end

    post "#{path_guid}/copy_bits", :copy_app_bits
    def copy_app_bits(dest_app_guid)
      json_request = MultiJson.load(body)
      source_app_guid = json_request['source_app_guid']

      raise CloudController::Errors::ApiError.new_from_details('AppBitsCopyInvalid', 'missing source_app_guid') unless source_app_guid

      src_app = find_guid_and_validate_access(:upload, source_app_guid)
      dest_app = find_guid_and_validate_access(:upload, dest_app_guid)

      app_bits_copier = Jobs::Runtime::AppBitsCopier.new(
        src_app,
        dest_app,
        @app_event_repository,
        SecurityContext.current_user,
        SecurityContext.current_user_email
      )

      job = Jobs::Enqueuer.new(app_bits_copier, queue: 'cc-generic').enqueue
      [HTTP::CREATED, JobPresenter.new(job).to_json]
    end

    private

    def json_param(name)
      raw = params[name]
      MultiJson.load(raw)
    rescue MultiJson::ParseError
      raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', "invalid :#{name}")
    end

    def packer_class
      CloudController::DependencyLocator.instance.packer_class
    end
  end
end
