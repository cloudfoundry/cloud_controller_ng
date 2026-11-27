require 'messages/resource_match_create_message'
require 'presenters/v3/resource_match_presenter'

class ResourceMatchesController < ApplicationController
  def create
    unauthorized! unless current_user
    FeatureFlag.raise_unless_enabled!(:app_bits_upload)

    message = VCAP::CloudController::ResourceMatchCreateMessage.new(hashed_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    resource_count = message.resources&.size || 0
    logger.info('resource_match.request.start', {
                  user_guid: current_user.guid,
                  resource_count: resource_count
                })

    start_time = Time.now
    fingerprints_v2_response = if FeatureFlag.enabled?(:resource_matching)
                                 CloudController::DependencyLocator.instance.resource_pool_wrapper.new(message.v2_fingerprints_body).call
                               else
                                 [].to_json
                               end

    matched_fingerprints = Oj.load(fingerprints_v2_response)
    matched_count = matched_fingerprints.size

    logger.info('resource_match.request.done', {
                  user_guid: current_user.guid,
                  resource_count: resource_count,
                  matched_count: matched_count,
                  missing_count: resource_count - matched_count,
                  duration_ms: elapsed_ms(start_time)
                })

    render status: :created, json: Presenters::V3::ResourceMatchPresenter.new(matched_fingerprints)
  end

  private

  def elapsed_ms(start_time)
    ((Time.now - start_time) * 1000).round
  end
end
