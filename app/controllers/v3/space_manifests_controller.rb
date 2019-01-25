require 'controllers/v3/mixins/app_sub_resource'
require 'presenters/v3/app_manifest_presenter'
require 'repositories/app_event_repository'

class SpaceManifestsController < ApplicationController
  include AppSubResource

  YAML_CONTENT_TYPE = 'application/x-yaml'.freeze

  wrap_parameters :body, format: [:yaml]

  before_action :validate_content_type!, only: :apply_manifest

  def apply_manifest
    message = AppManifestMessage.create_from_yml(parsed_app_manifest_params)
    compound_error!(message.errors.full_messages) unless message.valid?

    app, space = get_resources_for_space_manifest(hashed_params[:guid], parsed_app_manifest_params['name'])

    unauthorized! unless permission_queryer.can_write_to_space?(space.guid)
    unsupported_for_docker_apps!(message) if app && incompatible_with_buildpacks(app.lifecycle_type, message)

    apply_manifest_action = AppApplyManifest.new(user_audit_info)
    apply_manifest_job = VCAP::CloudController::Jobs::ApplyManifestActionJob.new(app.guid, message, apply_manifest_action)

    record_apply_manifest_audit_event(app, message, space)
    job = Jobs::Enqueuer.new(apply_manifest_job, queue: 'cc-generic').enqueue_pollable

    url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
    head HTTP::ACCEPTED, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}")
  end

  private

  def get_resources_for_space_manifest(space_guid, app_name)
    space = Space.find(guid: space_guid)
    space_not_found! unless space && permission_queryer.can_read_from_space?(space.guid, space.organization.guid)

    app = AppModel.find(name: app_name)
    [app, space]
  end

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

  def space_not_found!
    resource_not_found!('space')
  end
end
