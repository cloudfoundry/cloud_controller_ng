require 'cloud_controller/errors/compound_error'

module ErrorsHelper
  def invalid_request!(message)
    raise CloudController::Errors::ApiError.new_from_details('InvalidRequest', message)
  end

  def invalid_param!(message)
    raise CloudController::Errors::ApiError.new_from_details('BadQueryParameter', message)
  end

  def unprocessable(message)
    CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', message)
  end

  def unprocessable!(message)
    raise unprocessable(message)
  end

  def unauthorized!
    raise CloudController::Errors::ApiError.new_from_details('NotAuthorized')
  end

  def resource_not_found_with_message!(message)
    raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', message)
  end

  def bad_request!(message)
    raise CloudController::Errors::ApiError.new_from_details('BadRequest', message)
  end

  def message_parse_error!(message)
    raise CloudController::Errors::ApiError.new_from_details('MessageParseError', message)
  end

  def service_unavailable!(message)
    raise CloudController::Errors::ApiError.new_from_details('ServiceUnavailable', message)
  end

  def resource_not_found!(resource)
    raise CloudController::Errors::NotFound.new_from_details('ResourceNotFound', "#{resource.to_s.humanize} not found")
  end

  def not_found!
    raise CloudController::Errors::NotFound.new_from_details('NotFound')
  end

  def blobstore_error(message)
    CloudController::Errors::ApiError.new_from_details('BlobstoreError', message)
  end

  def blobstore_error!(message)
    raise blobstore_error(message)
  end

  def compound_error(errors)
    CloudController::Errors::CompoundError.new(errors)
  end

  def compound_error!(errors)
    raise compound_error(errors)
  end
end
