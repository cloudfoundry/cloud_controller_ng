require 'messages/resource_match_create_message'
require 'presenters/v3/resource_match_presenter'

class ResourceMatchesController < ApplicationController
  def create
    unauthorized! unless current_user
    FeatureFlag.raise_unless_enabled!(:app_bits_upload)

    message = VCAP::CloudController::ResourceMatchCreateMessage.new(hashed_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    fingerprints_v2_response = if FeatureFlag.enabled?(:resource_matching)
                                 resource_pool_wrapper.new(message.v2_fingerprints_body).call
                               else
                                 [].to_json
                               end

    render status: :created, json: Presenters::V3::ResourceMatchPresenter.new(fingerprints_v2_response)
  end

  private

  def resource_pool_wrapper
    CloudController::DependencyLocator.instance.resource_pool_wrapper
  end
end
