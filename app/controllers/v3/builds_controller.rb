require 'messages/builds/build_create_message'
require 'presenters/v3/build_presenter'
require 'actions/build_create'

class BuildsController < ApplicationController
  def create
    message = BuildCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    package = PackageModel.where(guid: message.package_guid).
              eager(:app, :space, space: :organization, app: :buildpack_lifecycle_data).all.first
    unprocessable_package! unless package
    package_not_accessible! unless can_read?(package.space.guid, package.space.organization.guid)
    staging_in_progress! if package.app.staging_in_progress?

    FeatureFlag.raise_unless_enabled!(:diego_docker) if package.type == PackageModel::DOCKER_TYPE
    unauthorized! unless can_write?(package.space.guid)

    lifecycle = LifecycleProvider.provide(package, message)
    unprocessable!(lifecycle.errors.full_messages) unless lifecycle.valid?

    build = BuildCreate.new.create_and_stage(
      package: package,
      lifecycle: lifecycle,
      message: message,
      user_audit_info: user_audit_info)

    render status: :created, json: Presenters::V3::BuildPresenter.new(build)
  rescue BuildCreate::InvalidPackage => e
    invalid_request!(e.message)
  rescue BuildCreate::SpaceQuotaExceeded => e
    unprocessable!("space's memory limit exceeded: #{e.message}")
  rescue BuildCreate::OrgQuotaExceeded => e
    unprocessable!("organization's memory limit exceeded: #{e.message}")
  rescue BuildCreate::DiskLimitExceeded
    unprocessable!('disk limit exceeded')
  end

  private

  def build_not_found!
    resource_not_found!(:build)
  end

  def package_not_accessible!
    resource_not_found!(:package)
  end

  def unprocessable_package!
    unprocessable!('Unable to use package. Ensure that the package exists and you have access to it.')
  end

  def staging_in_progress!
    raise CloudController::Errors::ApiError.new_from_details('StagingInProgress')
  end
end
