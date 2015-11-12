module V3ErrorsHelper
  def invalid_request!(message)
    raise VCAP::Errors::ApiError.new_from_details('InvalidRequest', message)
  end

  def invalid_param!(message)
    raise VCAP::Errors::ApiError.new_from_details('BadQueryParameter', message)
  end

  def unprocessable!(message)
    raise VCAP::Errors::ApiError.new_from_details('UnprocessableEntity', message)
  end

  def unauthorized!
    raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
  end
end

class ApplicationController < ActionController::Base
  include VCAP::CloudController
  include V3ErrorsHelper

  wrap_parameters :body, format: [:json, :url_encoded_form, :multipart_form]

  before_action :set_locale
  around_action :manage_request_id
  before_action :set_current_user, except: [:internal_error]
  before_action :validate_scheme!, except: [:not_found, :internal_error, :bad_request]
  before_action :validate_token!, except: [:not_found, :internal_error, :bad_request]
  before_action :check_read_permissions!, only: [:index, :show, :show_environment]
  before_action :check_write_permissions!, except: [:index, :show, :not_found, :internal_error, :bad_request]
  before_action :null_coalesce_body

  rescue_from VCAP::Errors::ApiError, with: :handle_api_error

  def configuration
    Config.config
  end

  def query_params
    request.query_parameters.with_indifferent_access
  end

  def roles
    VCAP::CloudController::SecurityContext.roles
  end

  def current_user
    VCAP::CloudController::SecurityContext.current_user
  end

  def current_user_email
    VCAP::CloudController::SecurityContext.current_user_email
  end

  def request_id
    ::VCAP::Request.current_id
  end

  def logger
    @logger ||= Steno.logger('cc.api')
  end

  private

  ###
  ### FILTERS
  ###

  def manage_request_id
    ::VCAP::Request.current_id = request.env['cf.request_id']
    yield
  ensure
    ::VCAP::Request.current_id = nil
  end

  def check_read_permissions!
    read_scope = SecurityContext.scopes.include?('cloud_controller.read')
    raise VCAP::Errors::ApiError.new_from_details('NotAuthorized') if !roles.admin? && !read_scope
  end

  def check_write_permissions!
    write_scope = SecurityContext.scopes.include?('cloud_controller.write')
    raise VCAP::Errors::ApiError.new_from_details('NotAuthorized') if !roles.admin? && !write_scope
  end

  def set_current_user
    auth_token = request.headers['HTTP_AUTHORIZATION']
    token_decoder = VCAP::UaaTokenDecoder.new(configuration[:uaa])
    VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder).configure(auth_token)
    logger.info("User for request: #{current_user.nil? ? nil : current_user.guid}")
  end

  def validate_scheme!
    validator = VCAP::CloudController::RequestSchemeValidator.new
    validator.validate!(current_user, roles, configuration, request)
  end

  def set_locale
    I18n.locale = request.headers['HTTP_ACCEPT_LANGUAGE']
  end

  def validate_token!
    return if current_user

    if VCAP::CloudController::SecurityContext.missing_token?
      raise VCAP::Errors::ApiError.new_from_details('NotAuthenticated')
    elsif VCAP::CloudController::SecurityContext.invalid_token?
      raise VCAP::Errors::ApiError.new_from_details('InvalidAuthToken')
    end

    raise VCAP::Errors::ApiError.new_from_details('InvalidAuthToken')
  end

  def handle_api_error(error)
    presenter = ErrorPresenter.new(error, Rails.env.test?)
    logger.info(presenter.log_message)
    render status: presenter.response_code, json: MultiJson.dump(presenter.error_hash, pretty: true)
  end

  def null_coalesce_body
    params[:body] ||= {}
  end
end
