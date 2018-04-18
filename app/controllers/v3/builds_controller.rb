require 'messages/build_create_message'
require 'messages/builds_list_message'
require 'fetchers/build_list_fetcher'
require 'presenters/v3/build_presenter'
require 'actions/build_create'

class BuildsController < ApplicationController
  def index
    message = BuildsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?
    build_list_fetcher = BuildListFetcher.new(message: message)
    dataset = if can_read_globally?
                build_list_fetcher.fetch_all
              else
                build_list_fetcher.fetch_for_spaces(space_guids: readable_space_guids)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(dataset: dataset, path: '/v3/builds', message: message)
  end

  def create
    message = BuildCreateMessage.new(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    package = PackageModel.where(guid: message.package_guid).
              eager(:app, :space, space: :organization, app: :buildpack_lifecycle_data).all.first
    unprocessable_package! unless package
    package_not_accessible! unless can_read?(package.space.guid, package.space.organization.guid)

    FeatureFlag.raise_unless_enabled!(:diego_docker) if package.type == PackageModel::DOCKER_TYPE
    unauthorized! unless can_write?(package.space.guid)

    lifecycle = LifecycleProvider.provide(package, message)
    unprocessable!(lifecycle.errors.full_messages) unless lifecycle.valid?

    build = BuildCreate.new.create_and_stage(
      package: package,
      lifecycle: lifecycle)

    render status: :created, json: Presenters::V3::BuildPresenter.new(build)
  rescue BuildCreate::InvalidPackage => e
    invalid_request!(e.message)
  rescue BuildCreate::SpaceQuotaExceeded => e
    unprocessable!("space's memory limit exceeded: #{e.message}")
  rescue BuildCreate::OrgQuotaExceeded => e
    unprocessable!("organization's memory limit exceeded: #{e.message}")
  rescue BuildCreate::DiskLimitExceeded
    unprocessable!('disk limit exceeded')
  rescue BuildCreate::StagingInProgress
    raise CloudController::Errors::ApiError.new_from_details('StagingInProgress')
  rescue BuildCreate::BuildError => e
    unprocessable!(e.message)
  end

  def show
    build = BuildModel.find(guid: params[:guid])

    build_not_found! unless build && can_read?(build.package.space.guid, build.package.space.organization.guid)

    render status: :ok, json: Presenters::V3::BuildPresenter.new(build)
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
end
