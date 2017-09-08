require 'messages/apps/app_feature_update_message'
require 'controllers/v3/mixins/sub_resource'

class AppFeaturesController < ApplicationController
  include SubResource

  def index
    app, space, org = AppFetcher.new.fetch(params[:guid])
    app_not_found! unless app && can_read?(space.guid, org.guid)
    render status: :ok, json: {
      pagination: {},
      resources:   [feature_ssh(app),]
    }
  end

  def show
    app, space, org = AppFetcher.new.fetch(params[:guid])
    app_not_found! unless app && can_read?(space.guid, org.guid)
    resource_not_found!(:feature) unless params[:name] == 'ssh'

    render status: :ok, json: feature_ssh(app)
  end

  def update
    app, space, org = AppFetcher.new.fetch(params[:guid])

    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)
    resource_not_found!(:feature) unless params[:name] == 'ssh'

    message = VCAP::CloudController::AppFeatureUpdateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app.update(enable_ssh: message.enabled)

    render status: :ok, json: feature_ssh(app)
  end

  private

  def feature_ssh(app)
    {
      name:        'ssh',
      description: 'Enable SSHing into the app.',
      enabled:     app.enable_ssh,
    }
  end
end
