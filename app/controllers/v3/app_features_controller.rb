require 'messages/apps/app_feature_update_message'
require 'controllers/v3/mixins/app_sub_resource'
require 'presenters/v3/app_feature_presenter'

class AppFeaturesController < ApplicationController
  include AppSubResource

  def index
    app, space, org = AppFetcher.new.fetch(params[:app_guid])
    app_not_found! unless app && can_read?(space.guid, org.guid)

    resources = [Presenters::V3::AppFeaturePresenter.new(app)]
    pagination_presenter = Presenters::V3::PaginationPresenter.new

    render status: :ok, json: {
      resources:  resources,
      pagination: pagination_presenter.present_unpagination_hash(resources, base_url(resource: 'features')),
    }
  end

  def show
    app, space, org = AppFetcher.new.fetch(params[:app_guid])
    app_not_found! unless app && can_read?(space.guid, org.guid)
    resource_not_found!(:feature) unless params[:name] == 'ssh'

    render status: :ok, json: Presenters::V3::AppFeaturePresenter.new(app)
  end

  def update
    app, space, org = AppFetcher.new.fetch(params[:app_guid])

    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)
    resource_not_found!(:feature) unless params[:name] == 'ssh'

    message = VCAP::CloudController::AppFeatureUpdateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app.update(enable_ssh: message.enabled)

    render status: :ok, json: Presenters::V3::AppFeaturePresenter.new(app)
  end
end
