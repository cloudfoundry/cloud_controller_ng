require 'messages/builds/build_create_message'
require 'presenters/v3/build_presenter'

class BuildsController < ApplicationController
  def create
    message = VCAP::CloudController::BuildCreateMessage.create_from_http_request(params[:body])

    package = VCAP::CloudController::PackageModel.where(guid: message.package_guid).eager(:app, :space, space: :organization, app: :buildpack_lifecycle_data).all.first
    lifecycle = VCAP::CloudController::LifecycleProvider.provide(package, message)

    build = VCAP::CloudController::BuildModel.create(state: 'STAGING')

    droplet = VCAP::CloudController::DropletCreate.new.create_and_stage(
      package: package,
      lifecycle: lifecycle,
      message: message,
      user_audit_info: user_audit_info
    )

    build.update(droplet: droplet)

    render status: 201, json: VCAP::CloudController::Presenters::V3::BuildPresenter.new(build).to_hash
  end
end
