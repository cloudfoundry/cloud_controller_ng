require 'messages/app_feature_update_message'
require 'controllers/v3/mixins/app_sub_resource'
require 'presenters/v3/app_feature_presenter'
require 'presenters/v3/app_ssh_status_presenter'

class AppFeaturesController < ApplicationController
  include AppSubResource

  def index
    app, space, org = AppFetcher.new.fetch(hashed_params[:app_guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)

    resources = [Presenters::V3::AppFeaturePresenter.new(app)]

    render status: :ok, json: {
      resources:  resources,
      pagination: present_unpagination_hash(resources, base_url(resource: 'features')),
    }
  end

  def show
    app, space, org = AppFetcher.new.fetch(hashed_params[:app_guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)
    resource_not_found!(:feature) unless hashed_params[:name] == 'ssh'

    render status: :ok, json: Presenters::V3::AppFeaturePresenter.new(app)
  end

  def update
    app, space, org = AppFetcher.new.fetch(hashed_params[:app_guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(space.guid)
    resource_not_found!(:feature) unless hashed_params[:name] == 'ssh'

    message = VCAP::CloudController::AppFeatureUpdateMessage.new(hashed_params['body'])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app.update(enable_ssh: message.enabled)

    render status: :ok, json: Presenters::V3::AppFeaturePresenter.new(app)
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
end
