require 'cloud_controller/blobstore/errors'

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

  def resources_not_found!(message)
    raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', message)
  end

  def resource_not_found!(resource)
    raise CloudController::Errors::NotFound.new_from_details('ResourceNotFound', "#{resource.to_s.humanize} not found")
  end
end

class ApplicationController < ActionController::Base
  include VCAP::CloudController
  include V3ErrorsHelper

  UNSCOPED_PAGES = ['not_found', 'internal_error', 'bad_request', 'v3_root'].map(&:freeze).freeze
  READ_SCOPE_HTTP_METHODS = ['GET', 'HEAD'].map(&:freeze).freeze

  wrap_parameters :body, format: [:json, :url_encoded_form, :multipart_form]

  before_action :set_locale
  before_action :validate_token!, except: [:not_found, :internal_error, :bad_request]
  before_action :check_read_permissions!, if: :enforce_read_scope?
  before_action :check_write_permissions!, if: :enforce_write_scope?
  before_action :null_coalesce_body

  rescue_from CloudController::Blobstore::BlobstoreError, with: :handle_blobstore_error
  rescue_from CloudController::Errors::NotAuthenticated, with: :handle_not_authenticated
  rescue_from CloudController::Errors::NotFound, with: :handle_not_found
  rescue_from CloudController::Errors::InvalidAuthToken, with: :handle_invalid_auth_token
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

  def user_audit_info
    VCAP::CloudController::UserAuditInfo.from_context(VCAP::CloudController::SecurityContext)
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

  def can_write_to_org?(org_guid)
    VCAP::CloudController::Permissions.new(current_user).can_write_to_org?(org_guid)
  end

  def can_read_from_org?(org_guid)
    VCAP::CloudController::Permissions.new(current_user).can_read_from_org?(org_guid)
  end

  def can_write_globally?
    VCAP::CloudController::Permissions.new(current_user).can_write_globally?
  end

  def can_read_globally?
    VCAP::CloudController::Permissions.new(current_user).can_read_globally?
  end

  def can_read_from_isolation_segment?(isolation_segment)
    VCAP::CloudController::Permissions.new(current_user).can_read_from_isolation_segment?(isolation_segment)
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

  def readable_org_guids
    VCAP::CloudController::Permissions.new(current_user).readable_org_guids
  end

  ###
  ### FILTERS
  ###

  def enforce_read_scope?
    return false if UNSCOPED_PAGES.include?(action_name)

    READ_SCOPE_HTTP_METHODS.include?(request.method)
  end

  def enforce_write_scope?
    return false if UNSCOPED_PAGES.include?(action_name)

    !READ_SCOPE_HTTP_METHODS.include?(request.method)
  end

  def check_read_permissions!
    read_scope = SecurityContext.scopes.include?('cloud_controller.read')
    admin_read_only_scope = SecurityContext.scopes.include?('cloud_controller.admin_read_only')
    global_auditor_scope = SecurityContext.scopes.include?('cloud_controller.global_auditor')

    raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') if !roles.admin? && !read_scope && !admin_read_only_scope && !global_auditor_scope
  end

  def check_write_permissions!
    write_scope = SecurityContext.scopes.include?('cloud_controller.write')
    raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') if !roles.admin? && !write_scope
  end

  def set_locale
    I18n.locale = request.headers['HTTP_ACCEPT_LANGUAGE']
  end

  def validate_token!
    return if current_user

    if VCAP::CloudController::SecurityContext.missing_token?
      raise CloudController::Errors::NotAuthenticated
    end

    raise CloudController::Errors::InvalidAuthToken
  end

  def handle_blobstore_error(error)
    error = CloudController::Errors::ApiError.new_from_details('BlobstoreError', error.message)
    handle_api_error(error)
  end

  def handle_exception(error)
    presenter = ErrorPresenter.new(error, Rails.env.test?, V3ErrorHasher.new(error))
    logger.info(presenter.log_message)
    render status: presenter.response_code, json: presenter
  end
  alias_method :handle_not_authenticated, :handle_exception
  alias_method :handle_api_error, :handle_exception
  alias_method :handle_not_found, :handle_exception
  alias_method :handle_invalid_auth_token, :handle_exception

  def null_coalesce_body
    params[:body] ||= {}
  end

  def membership
    @membership ||= Membership.new(current_user)
  end
end
