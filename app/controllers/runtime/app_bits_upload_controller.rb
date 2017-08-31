require 'presenters/api/job_presenter'

module VCAP::CloudController
  class AppBitsUploadController < RestController::ModelController
    def self.dependencies
      [:app_event_repository]
    end

    def inject_dependencies(dependencies)
      super
      @app_event_repository = dependencies.fetch(:app_event_repository)
    end

    path_base 'apps'
    model_class_name :ProcessModel
    self.not_found_exception_name = 'AppNotFound'

    def check_authentication(op)
      auth                  = env['HTTP_AUTHORIZATION']
      grace_period          = config.get(:app_bits_upload_grace_period_in_seconds) || 0
      relaxed_token_decoder = VCAP::CloudController::UaaTokenDecoder.new(config.get(:uaa), grace_period)
      VCAP::CloudController::Security::SecurityContextConfigurer.new(relaxed_token_decoder).configure(auth)
      super
    end

    put "#{path_guid}/bits", :upload

    def upload(guid)
      process = find_guid_and_validate_access(:upload, guid)

      raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'cannot upload bits to a docker app') if process.docker?

      relationships  = { app: { data: { guid: process.app.guid } } }
      create_message = PackageCreateMessage.new({ type: 'bits', relationships: relationships })
      package        = PackageCreate.create_without_event(create_message)

      unless params['resources']
        missing_resources_message = 'missing :resources'
        package.fail_upload!(missing_resources_message)
        raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', missing_resources_message)
      end

      upload_handler = CloudController::DependencyLocator.instance.upload_handler
      upload_message = PackageUploadMessage.new({
        bits_path:        upload_handler.uploaded_file(request.POST, 'application'),
        bits_name:        upload_handler.uploaded_filename(request.POST, 'application'),
        cached_resources: json_param('resources')
      })
      uploader = PackageUpload.new

      if async?
        enqueued_job = uploader.upload_async_without_event(
          message: upload_message,
          package: package,
          config:  config,
        )
        result = [HTTP::CREATED, JobPresenter.new(enqueued_job).to_json]
      else
        uploader.upload_sync_without_event(upload_message, package)
        result = [HTTP::CREATED, '{}']
      end
      record_upload_bits(package)
      result
    end

    post "#{path_guid}/copy_bits", :copy_app_bits

    def copy_app_bits(dest_app_guid)
      json_request        = MultiJson.load(body)
      source_process_guid = json_request['source_app_guid']

      raise CloudController::Errors::ApiError.new_from_details('AppBitsCopyInvalid', 'missing source_app_guid') unless source_process_guid

      src_process  = find_guid_and_validate_access(:upload, source_process_guid)
      dest_process = find_guid_and_validate_access(:upload, dest_app_guid)

      copier = PackageCopy.new
      copier.copy_without_event(dest_process.app.guid, src_process.latest_package)

      @app_event_repository.record_src_copy_bits(dest_process, src_process, UserAuditInfo.from_context(SecurityContext))
      @app_event_repository.record_dest_copy_bits(dest_process, src_process, UserAuditInfo.from_context(SecurityContext))

      [HTTP::CREATED, JobPresenter.new(copier.enqueued_job).to_json]
    end

    private

    def record_upload_bits(package)
      Repositories::PackageEventRepository.record_app_upload_bits(
        package,
        UserAuditInfo.from_context(SecurityContext))
    end

    def json_param(name)
      raw = params[name]
      MultiJson.load(raw)
    rescue MultiJson::ParseError
      raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', "invalid :#{name}")
    end
  end
end
