require 'presenters/v3/space_ssh_feature_presenter'

class SpaceFeaturesController < ApplicationController
  SPACE_FEATURE = 'ssh'.freeze

  def show
    space = SpaceFetcher.new.fetch(hashed_params[:guid])
    resource_not_found!(:space) unless space && permission_queryer.can_read_from_space?(space.guid, space.organization.guid)
    resource_not_found!(:feature) unless SPACE_FEATURE == hashed_params[:name]

    render status: :ok, json: Presenters::V3::SpaceSshFeaturePresenter.new(space)
  end
end
