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
    model_class_name :App

    def check_authentication(op)
      auth                  = env['HTTP_AUTHORIZATION']
      grace_period          = config.fetch(:app_bits_upload_grace_period_in_seconds, 0)
      relaxed_token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa], grace_period)
      VCAP::CloudController::Security::SecurityContextConfigurer.new(relaxed_token_decoder).configure(auth)
      super
    end

    put "#{path_guid}/bits", :upload
    def upload(guid)
      app = find_guid_and_validate_access(:upload, guid)

      raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'cannot upload bits to a docker app') if app.docker?

      create_message = PackageCreateMessage.new({ type: 'bits', app_guid: app.app.guid })
      package = PackageCreate.create_without_event(create_message)

      unless params['resources']
        missing_resources_message = 'missing :resources'
        package.fail_upload!(missing_resources_message)
        raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', missing_resources_message)
      end

      upload_handler = CloudController::DependencyLocator.instance.upload_handler
      upload_message = PackageUploadMessage.new({
        bits_path:        upload_handler.uploaded_file(params, 'application'),
        bits_name:        upload_handler.uploaded_filename(params, 'application'),
        cached_resources: json_param('resources')
      })
      uploader = PackageUpload.new

      if async?
        enqueued_job = uploader.upload_async_without_event(
          message:    upload_message,
          package:    package,
          config:     config,
        )
        [HTTP::CREATED, JobPresenter.new(enqueued_job).to_json]
      else
        uploader.upload_sync_without_event(upload_message, package)
        [HTTP::CREATED, '{}']
      end
    end

    post "#{path_guid}/copy_bits", :copy_app_bits
    def copy_app_bits(dest_app_guid)
      json_request    = MultiJson.load(body)
      source_app_guid = json_request['source_app_guid']

      raise CloudController::Errors::ApiError.new_from_details('AppBitsCopyInvalid', 'missing source_app_guid') unless source_app_guid

      src_app  = find_guid_and_validate_access(:upload, source_app_guid)
      dest_app = find_guid_and_validate_access(:upload, dest_app_guid)

      copier = PackageCopy.new
      copier.copy_without_event(dest_app.app.guid, src_app.latest_package)

      @app_event_repository.record_src_copy_bits(dest_app, src_app, SecurityContext.current_user.guid, SecurityContext.current_user_email)
      @app_event_repository.record_dest_copy_bits(dest_app, src_app, SecurityContext.current_user.guid, SecurityContext.current_user_email)

      [HTTP::CREATED, JobPresenter.new(copier.enqueued_job).to_json]
    end

    private

    def json_param(name)
      raw = params[name]
      MultiJson.load(raw)
    rescue MultiJson::ParseError
      raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', "invalid :#{name}")
    end
  end
end
