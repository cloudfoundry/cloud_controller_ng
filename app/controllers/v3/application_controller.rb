require 'cloud_controller/blobstore/errors'
require 'cloud_controller/errors/compound_error'

module V3ErrorsHelper
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
end

class ApplicationController < ActionController::Base
  include VCAP::CloudController
  include V3ErrorsHelper
  include VCAP::CloudController::ParamsHashifier

  ANONYMOUSLY_AVAILABLE = ['not_found', 'internal_error', 'bad_request', 'v3_info'].map(&:freeze).freeze
  UNSCOPED_PAGES = ['not_found', 'internal_error', 'bad_request', 'v3_root', 'v3_info'].map(&:freeze).freeze
  READ_SCOPE_HTTP_METHODS = ['GET', 'HEAD'].map(&:freeze).freeze
  YAML_CONTENT_TYPE = 'application/x-yaml'.freeze

  wrap_parameters :body, format: [:json, :url_encoded_form, :multipart_form]

  before_action :validate_token!, if: :enforce_authentication?
  before_action :check_read_permissions!, if: :enforce_read_scope?
  before_action :check_write_permissions!, if: :enforce_write_scope?
  before_action :hashify_params
  before_action :null_coalesce_body

  rescue_from CloudController::Blobstore::BlobstoreError, with: :handle_blobstore_error
  rescue_from CloudController::Errors::NotAuthenticated, with: :handle_not_authenticated
  rescue_from CloudController::Errors::NotFound, with: :handle_not_found
  rescue_from CloudController::Errors::InvalidAuthToken, with: :handle_invalid_auth_token
  rescue_from CloudController::Errors::ApiError, with: :handle_api_error
  rescue_from CloudController::Errors::CompoundError, with: :handle_compound_error

  def configuration
    Config.config
  end

  def query_params
    request.query_parameters.with_indifferent_access
  end

  def unmunged_body
    JSON.parse(request.body.string)
  end

  def parsed_yaml
    return @parsed_yaml if @parsed_yaml

    allow_yaml_aliases = false
    yaml = YAML.safe_load(request.body.string, [], [], allow_yaml_aliases)
    message_parse_error!('invalid request body') if !yaml.is_a? Hash
    @parsed_yaml = yaml
  rescue Psych::BadAlias
    bad_request!('Manifest does not support Anchors and Aliases')
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

  def url_builder
    @url_builder ||= VCAP::CloudController::Presenters::ApiUrlBuilder
  end

  def request_id
    ::VCAP::Request.current_id
  end

  def logger
    @logger ||= Steno.logger('cc.api')
  end

  def perm_client
    @perm_client ||= CloudController::DependencyLocator.instance.perm_client
  end

  def statsd_client
    @statsd_client ||= CloudController::DependencyLocator.instance.statsd_client
  end

  def permission_queryer
    @permission_queryer ||= VCAP::CloudController::Permissions::Queryer.build(
      perm_client,
      statsd_client,
      SecurityContext,
      configuration.get(:perm, :enabled),
      configuration.get(:perm, :query_raise_on_mismatch)
    )
  end

  def add_warning_headers(warnings)
    return if warnings.nil?
    raise ArgumentError.new('warnings should be an array') unless warnings.is_a?(Array)

    warnings.each do |warning|
      response.add_header('X-Cf-Warnings', CGI.escape(warning))
    end
  end

  private

  ###
  ### FILTERS
  ###

  def enforce_authentication?
    !ANONYMOUSLY_AVAILABLE.include?(action_name)
  end

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
  alias_method :handle_compound_error, :handle_exception
  alias_method :handle_not_found, :handle_exception
  alias_method :handle_invalid_auth_token, :handle_exception

  def null_coalesce_body
    hashed_params[:body] ||= {}
  end

  def membership
    @membership ||= Membership.new(current_user)
  end
end
