class ErrorsController <  ApplicationController
  def not_found
    error =  VCAP::Errors::ApiError.new_from_details('NotFound')
    presenter = ErrorPresenter.new(error, Rails.env.test?)
    render status: :not_found, json: MultiJson.dump(presenter.error_hash, pretty: true)
  end

  def internal_error
    error = request.env['action_dispatch.exception']
    presenter = ErrorPresenter.new(error, Rails.env.test?)
    logger.error(presenter.log_message)
    render status: presenter.response_code, json: MultiJson.dump(presenter.error_hash, pretty: true)
  end

  def bad_request
    error = VCAP::Errors::ApiError.new_from_details('InvalidRequest')

    if request.env['action_dispatch.exception'].is_a?(ActionDispatch::ParamsParser::ParseError)
      error = VCAP::Errors::ApiError.new_from_details('MessageParseError', 'invalid request body')
    end

    presenter = ErrorPresenter.new(error, Rails.env.test?)
    render status: presenter.response_code, json: MultiJson.dump(presenter.error_hash, pretty: true)
  end
end
