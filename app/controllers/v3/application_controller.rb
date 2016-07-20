module V3ErrorsHelper
  def invalid_request!(message)
    raise CloudController::Errors::ApiError.new_from_details('InvalidRequest', message)
  end

  def invalid_param!(message)
    raise CloudController::Errors::ApiError.new_from_details('BadQueryParameter', message)
  end

  def unprocessable!(message)
    raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', message)
  end

  def unauthorized!
    raise CloudController::Errors::ApiError.new_from_details('NotAuthorized')
  end
end

class ApplicationController < ActionController::Base
  include VCAP::CloudController
  include V3ErrorsHelper

  wrap_parameters :body, format: [:json, :url_encoded_form, :multipart_form]

  before_action :set_locale
  around_action :manage_request_id
  before_action :validate_scheme!, except: [:not_found, :internal_error, :bad_request]
  before_action :validate_token!, except: [:not_found, :internal_error, :bad_request]
  before_action :check_read_permissions!, only: [:index, :show, :show_environment, :stats]
  before_action :check_write_permissions!, except: [:index, :show, :not_found, :internal_error, :bad_request]
  before_action :null_coalesce_body

  rescue_from CloudController::Blobstore::BlobstoreError, with: :handle_blobstore_error
  rescue_from CloudController::Errors::NotAuthenticated, with: :handle_not_authenticated
  rescue_from CloudController::Errors::ApiError, with: :handle_api_error

  def configuration
    Config.config
  end

  def query_params
    request.query_parameters.with_indifferent_access
  end

  def unmunged_body
    JSON.parse(request.body.string)
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
  ### PERMISSIONS
  ###

  def can_read?(space_guid, org_guid)
    VCAP::CloudController::Permissions.new(current_user).can_read_from_space?(space_guid, org_guid)
  end

  def can_see_secrets?(space)
    VCAP::CloudController::Permissions.new(current_user).can_see_secrets_in_space?(space.guid, space.organization.guid)
  end

  def can_write?(space_guid)
    VCAP::CloudController::Permissions.new(current_user).can_write_to_space?(space_guid)
  end

  def readable_space_guids
    VCAP::CloudController::Permissions.new(current_user).readable_space_guids
  end

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
    admin_read_only_scope = SecurityContext.scopes.include?('cloud_controller.admin_read_only')

    raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') if !roles.admin? && !read_scope && !admin_read_only_scope
  end

  def check_write_permissions!
    write_scope = SecurityContext.scopes.include?('cloud_controller.write')
    raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') if !roles.admin? && !write_scope
  end

  def validate_scheme!
    validator = CloudController::RequestSchemeValidator.new
    validator.validate!(current_user, roles, configuration, request)
  end

  def set_locale
    I18n.locale = request.headers['HTTP_ACCEPT_LANGUAGE']
  end

  def validate_token!
    return if current_user

    if VCAP::CloudController::SecurityContext.missing_token?
      raise CloudController::Errors::NotAuthenticated
    end

    raise CloudController::Errors::ApiError.new_from_details('InvalidAuthToken')
  end

  def handle_blobstore_error(error)
    error = CloudController::Errors::ApiError.new_from_details('BlobstoreError', error.message)
    handle_api_error(error)
  end

  def handle_not_authenticated(error)
    presenter = ErrorPresenter.new(error, Rails.env.test?)
    logger.info(presenter.log_message)
    render status: presenter.response_code, json: presenter
  end

  def handle_api_error(error)
    presenter = ErrorPresenter.new(error, Rails.env.test?)
    logger.info(presenter.log_message)
    render status: presenter.response_code, json: presenter
  end

  def null_coalesce_body
    params[:body] ||= {}
  end

  def membership
    @membership ||= Membership.new(current_user)
  end

  def resource_not_found!(resource)
    raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', "#{resource.to_s.humanize} not found")
  end
end
