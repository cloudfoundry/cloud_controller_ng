require 'controllers/v3/mixins/app_sub_resource'

class AppManifestsController < ApplicationController
  include AppSubResource

  wrap_parameters :body, format: [:yaml]

  def apply_manifest
    message = AppManifestMessage.create_from_http_request(parsed_app_manifest_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    app, space, org = AppFetcher.new.fetch(params[:guid])

    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)

    apply_manifest_action = AppApplyManifest.new(user_audit_info)
    apply_manifest_job = VCAP::CloudController::Jobs::ApplyManifestActionJob.new(app.guid, message, apply_manifest_action)

    job = Jobs::Enqueuer.new(apply_manifest_job, queue: 'cc-generic').enqueue_pollable

    url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
    head HTTP::ACCEPTED, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}")
  end

  private

  def validate_content_type!
    invalid_request!('Content-Type must be yaml') unless request_content_type_is_yaml?
  end

  def parsed_app_manifest_params
    parsed_application = params[:body]['applications'] && params[:body]['applications'].first

    raise invalid_request!('Invalid app manifest') unless parsed_application.present?
    parsed_application
  end
end
