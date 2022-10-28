require 'controllers/v3/mixins/app_sub_resource'
require 'presenters/v3/app_manifest_presenter'
require 'repositories/app_event_repository'

class AppManifestsController < ApplicationController
  include AppSubResource

  def show
    app, space = AppFetcher.new.fetch(hashed_params[:guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_read_secrets_in_space?(space.id, space.organization_id)

    manifest_presenter = Presenters::V3::AppManifestPresenter.new(app, app.service_bindings, app.route_mappings)
    manifest_yaml = manifest_presenter.to_hash.deep_stringify_keys.to_yaml
    render status: :ok, plain: manifest_yaml, content_type: YAML_CONTENT_TYPE
  end
end
