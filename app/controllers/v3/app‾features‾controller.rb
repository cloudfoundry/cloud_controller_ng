require 'messages/app_feature_update_message'
require 'controllers/v3/mixins/app_sub_resource'
require 'presenters/v3/app_ssh_feature_presenter'
require 'presenters/v3/app_revisions_feature_presenter'
require 'presenters/v3/app_ssh_status_presenter'
require 'actions/app_feature_update'

class AppFeaturesController < ApplicationController
  include AppSubResource

  APP_FEATURES = ['ssh', 'revisions'].freeze

  def index
    app, space, org = AppFetcher.new.fetch(hashed_params[:app_guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)
    resources = presented_app_features(app)

    render status: :ok, json: {
      resources:  resources,
      pagination: present_unpagination_hash(resources, base_url(resource: 'features')),
    }
  end

  def show
    app, space, org = AppFetcher.new.fetch(hashed_params[:app_guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)
    resource_not_found!(:feature) unless APP_FEATURES.include?(hashed_params[:name])

    render status: :ok, json: feature_presenter_for(hashed_params[:name], app)
  end

  def update
    app, space, org = AppFetcher.new.fetch(hashed_params[:app_guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(space.guid)
    resource_not_found!(:feature) unless APP_FEATURES.include?(hashed_params[:name])

    message = VCAP::CloudController::AppFeatureUpdateMessage.new(hashed_params['body'])
    unprocessable!(message.errors.full_messages) unless message.valid?

    AppFeatureUpdate.update(hashed_params[:name], app, message)
    render status: :ok, json: feature_presenter_for(hashed_params[:name], app)
  end

  def ssh_enabled
    app, space, org = AppFetcher.new.fetch(hashed_params[:guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)

    render status: :ok, json: Presenters::V3::AppSshStatusPresenter.new(app, Config.config.get(:allow_app_ssh_access))
  end

  private

  def present_unpagination_hash(result, path)
    {
      total_results: result.length,
      total_pages:   1,

      first:         { href: path },
      last:          { href: path },
      next:          nil,
      previous:      nil
    }
  end

  def feature_presenter_for(feature_name, app)
    presenters = {
      'ssh' => Presenters::V3::AppSshFeaturePresenter,
      'revisions' => Presenters::V3::AppRevisionsFeaturePresenter
    }
    presenters[feature_name].new(app)
  end

  def presented_app_features(app)
    [
      Presenters::V3::AppSshFeaturePresenter.new(app),
      Presenters::V3::AppRevisionsFeaturePresenter.new(app),
    ]
  end
end
