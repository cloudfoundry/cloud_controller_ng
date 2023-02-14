require 'messages/space_feature_update_message'
require 'presenters/v3/space_ssh_feature_presenter'

class SpaceFeaturesController < ApplicationController
  SPACE_FEATURE = 'ssh'.freeze

  def index
    space = Space.find(guid: hashed_params[:guid])
    resource_not_found!(:space) unless space && permission_queryer.can_read_from_space?(space.id, space.organization_id)

    render status: :ok, json: {
      resources: [Presenters::V3::SpaceSshFeaturePresenter.new(space)],
    }
  end

  def show
    space = SpaceFetcher.new.fetch(hashed_params[:guid])
    resource_not_found!(:space) unless space && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    resource_not_found!(:feature) unless hashed_params[:name] == SPACE_FEATURE

    render status: :ok, json: Presenters::V3::SpaceSshFeaturePresenter.new(space)
  end

  def update
    message = SpaceFeatureUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    space = SpaceFetcher.new.fetch(hashed_params[:guid])
    resource_not_found!(:space) unless space && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    resource_not_found!(:feature) unless hashed_params[:name] == SPACE_FEATURE
    unauthorized! unless permission_queryer.can_update_active_space?(space.id, space.organization_id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    space.update(allow_ssh: message.enabled)

    render status: :ok, json: Presenters::V3::SpaceSshFeaturePresenter.new(space)
  end
end
