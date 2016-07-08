require 'presenters/api/job_presenter'

module VCAP::CloudController
  class AppBitsUploadController < RestController::ModelController
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
      creator        = PackageCreate.new(SecurityContext.current_user.guid, SecurityContext.current_user_email)
      uploader       = PackageUpload.new(SecurityContext.current_user.guid, SecurityContext.current_user_email)

      package = creator.create(create_message)

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

      if async?
        enqueued_job = uploader.upload_async(upload_message, package, config)
        [HTTP::CREATED, JobPresenter.new(enqueued_job).to_json]
      else
        uploader.upload_sync(upload_message, package)
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

      copier = PackageCopy.new(SecurityContext.current_user.guid, SecurityContext.current_user_email)
      copier.copy(dest_app.app.guid, src_app.package)

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
