require 'presenters/v3/app_manifest_presenter'
require 'repositories/app_event_repository'
require 'messages/app_manifest_message'
require 'actions/app_find_or_create_skeleton'
require 'actions/app_create'
require 'actions/space_diff_manifest'

class SpaceManifestsController < ApplicationController
  wrap_parameters :body, format: [:yaml]

  before_action :validate_content_type!

  def apply_manifest
    space = Space.find(guid: hashed_params[:guid])
    space_not_found! unless space && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    can_write_space(space)

    messages = parsed_app_manifests.map { |app_manifest| AppManifestMessage.create_from_yml(app_manifest) }

    errors = messages.each_with_index.flat_map { |message, i| errors_for_message(message, i) }
    compound_error!(errors) unless errors.empty?

    action = AppFindOrCreateSkeleton.new(user_audit_info)
    app_guid_message_hash = messages.map do |m|
      begin
        app = action.find_or_create(message: m, space: space)
      rescue AppCreate::InvalidApp => e
        unprocessable!("For application '#{m.name}': " + e.message)
      end
      unsupported_for_docker_apps!(m) if incompatible_with_buildpacks(app.lifecycle_type, m)
      unsupported_for_buildpack_apps!(m) if incompatible_with_docker(app.lifecycle_type, m)

      [app.guid, m]
    end.to_h

    apply_manifest_action = AppApplyManifest.new(user_audit_info)
    apply_manifest_job = Jobs::SpaceApplyManifestActionJob.new(space, app_guid_message_hash, apply_manifest_action, user_audit_info)

    app_guid_message_hash.each { |app_guid, message| record_apply_manifest_audit_event(AppModel.find(guid: app_guid), message, space) }
    job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(apply_manifest_job)

    url_builder = Presenters::ApiUrlBuilder
    head HTTP::ACCEPTED, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}")
  end

  def diff_manifest
    space = Space.find(guid: hashed_params[:guid])
    space_not_found! unless space && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    can_write_space(space)

    parsed_manifests = parsed_app_manifests.map(&:to_hash)

    messages = parsed_app_manifests.map { |app_manifest| AppManifestMessage.create_from_yml(app_manifest) }
    errors = messages.each_with_index.flat_map { |message, i| errors_for_message(message, i) }
    compound_error!(errors) unless errors.empty?

    diff = SpaceDiffManifest.generate_diff(parsed_manifests, space)

    render status: :created, json: { diff: }
  end

  private

  def can_write_space(space)
    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)
  end

  def errors_for_message(message, index)
    return [] if message.valid?

    if message.name.present?
      message.errors.full_messages.map { |error| "For application '#{message.name}': #{error}" }
    else
      message.errors.full_messages.map { |error| "For application at index #{index}: #{error}" }
    end
  end

  def record_apply_manifest_audit_event(app, message, space)
    audited_request_yaml = { 'applications' => [message.audit_hash] }.to_yaml
    Repositories::AppEventRepository.new.record_app_apply_manifest(app, space, user_audit_info, audited_request_yaml)
  end

  def compound_error!(error_messages)
    underlying_errors = error_messages.map { |message| unprocessable(message) }
    raise CloudController::Errors::CompoundError.new(underlying_errors)
  end

  def validate_content_type!
    return if request_content_type_is_yaml?

    logger.error("Content-type isn't yaml: #{request.content_type}")
    bad_request!('Content-Type must be yaml')
  end

  def request_content_type_is_yaml?
    Mime::Type.lookup(request.content_type) == :yaml
  end

  def check_version_is_supported!
    version = parsed_yaml['version']
    raise unprocessable!('Unsupported manifest schema version. Currently supported versions: [1].') unless !version || version == 1
  end

  def parsed_app_manifests
    check_version_is_supported!
    parsed_applications = parsed_yaml['applications']
    raise unprocessable!("Cannot parse manifest with no 'applications' field.") if parsed_applications.blank?

    parsed_applications
  end

  def space_not_found!
    resource_not_found!('space')
  end

  def unsupported_for_docker_apps!(manifest)
    raise unprocessable("For application '#{manifest.name}': #{manifest.buildpacks ? 'Buildpacks' : 'Buildpack'} cannot be configured for a docker lifecycle app.")
  end

  def unsupported_for_buildpack_apps!(manifest)
    raise unprocessable("For application '#{manifest.name}': Docker cannot be configured for a buildpack lifecycle app.")
  end

  def incompatible_with_buildpacks(lifecycle_type, manifest)
    lifecycle_type == 'docker' && (manifest.buildpack || manifest.buildpacks)
  end

  def incompatible_with_docker(lifecycle_type, manifest)
    lifecycle_type == 'buildpack' && manifest.docker
  end
end
