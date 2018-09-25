require 'controllers/v3/mixins/app_sub_resource'
require 'presenters/v3/app_manifest_presenter'
require 'repositories/app_event_repository'

class AppManifestsController < ApplicationController
  include AppSubResource

  YAML_CONTENT_TYPE = 'application/x-yaml'.freeze

  wrap_parameters :body, format: [:yaml]

  before_action :validate_content_type!, only: :apply_manifest

  def apply_manifest
    message = AppManifestMessage.create_from_yml(parsed_app_manifest_params)
    compound_error!(message.errors.full_messages) unless message.valid?

    app, space, org = AppFetcher.new.fetch(hashed_params[:guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(space.guid)
    unsupported_for_docker_apps!(message) if incompatible_with_buildpacks(app.lifecycle_type, message)

    apply_manifest_action = AppApplyManifest.new(user_audit_info)
    apply_manifest_job = VCAP::CloudController::Jobs::ApplyManifestActionJob.new(app.guid, message, apply_manifest_action)

    record_apply_manifest_audit_event(app, message, space)
    job = Jobs::Enqueuer.new(apply_manifest_job, queue: 'cc-generic').enqueue_pollable

    url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
    head HTTP::ACCEPTED, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}")
  end

  def show
    app, space, org = AppFetcher.new.fetch(hashed_params[:guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)
    unauthorized! unless permission_queryer.can_read_secrets_in_space?(space.guid, org.guid)

    manifest_presenter = Presenters::V3::AppManifestPresenter.new(app, app.service_bindings, app.routes)
    manifest_yaml = manifest_presenter.to_hash.deep_stringify_keys.to_yaml
    render status: :ok, plain: manifest_yaml, content_type: YAML_CONTENT_TYPE
  end

  private

  def record_apply_manifest_audit_event(app, message, space)
    audited_request_yaml = { 'applications' => [message.audit_hash] }.to_yaml
    Repositories::AppEventRepository.new.record_app_apply_manifest(app, space, user_audit_info, audited_request_yaml)
  end

  def unsupported_for_docker_apps!(manifest)
    error_message = manifest.buildpacks ? 'Buildpacks' : 'Buildpack'
    raise unprocessable(error_message + ' cannot be configured for a docker lifecycle app.')
  end

  def incompatible_with_buildpacks(lifecycle_type, manifest)
    lifecycle_type == 'docker' && (manifest.buildpack || manifest.buildpacks)
  end

  def compound_error!(error_messages)
    underlying_errors = error_messages.map { |message| unprocessable(message) }
    raise CloudController::Errors::CompoundError.new(underlying_errors)
  end

  def validate_content_type!
    if !request_content_type_is_yaml?
      logger.error("Context-type isn't yaml: #{request.content_type}")
      invalid_request!('Content-Type must be yaml')
    end
  end

  def request_content_type_is_yaml?
    Mime::Type.lookup(request.content_type) == :yaml
  end

  def parsed_app_manifest_params
    parsed_application = params[:body]['applications'] && params[:body]['applications'].first

    raise invalid_request!('Invalid app manifest') unless parsed_application.present?
    parsed_application.to_unsafe_h
  end
end
