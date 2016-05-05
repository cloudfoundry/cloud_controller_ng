class ErrorsController < ApplicationController
  def not_found
    error = CloudController::Errors::ApiError.new_from_details('NotFound')
    presenter = ErrorPresenter.new(error, Rails.env.test?)
    render status: :not_found, json: presenter
  end

  def internal_error
    error = request.env['action_dispatch.exception']
    presenter = ErrorPresenter.new(error, Rails.env.test?)
    logger.error(presenter.log_message)
    render status: presenter.response_code, json: presenter
  end

  def bad_request
    error = CloudController::Errors::ApiError.new_from_details('InvalidRequest')

    if request.env['action_dispatch.exception'].is_a?(ActionDispatch::ParamsParser::ParseError)
      error = CloudController::Errors::ApiError.new_from_details('MessageParseError', 'invalid request body')
    end

    presenter = ErrorPresenter.new(error, Rails.env.test?)
    render status: presenter.response_code, json: presenter
  end
end
