require 'controllers/v3/mixins/app_sub_resource'

class AppManifestsController < ApplicationController
  include AppSubResource

  wrap_parameters :body, format: [:yaml]

  before_action :validate_content_type!

  def apply_manifest
    message = AppManifestMessage.create_from_http_request(parsed_app_manifest_params)
    compound_error!(message.errors.full_messages) unless message.valid?

    app, space, org = AppFetcher.new.fetch(params[:guid])

    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)

    apply_manifest_action = AppApplyManifest.new(user_audit_info, self)
    apply_manifest_job = VCAP::CloudController::Jobs::ApplyManifestActionJob.new(app.guid, message, apply_manifest_action)

    job = Jobs::Enqueuer.new(apply_manifest_job, queue: 'cc-generic').enqueue_pollable

    url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
    head HTTP::ACCEPTED, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}")
  end

  private

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
    parsed_application
  end
end
