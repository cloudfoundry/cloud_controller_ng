require 'messages/build_create_message'
require 'messages/builds_list_message'
require 'messages/build_update_message'
require 'fetchers/build_list_fetcher'
require 'presenters/v3/build_presenter'
require 'actions/build_create'
require 'actions/build_update'
require 'cloud_controller/telemetry_logger'

class BuildsController < ApplicationController
  def index
    message = BuildsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?
    dataset = if permission_queryer.can_read_globally?
                BuildListFetcher.fetch_all(message, eager_loaded_associations: Presenters::V3::BuildPresenter.associated_resources)
              else
                BuildListFetcher.fetch_for_spaces(message, space_guids: permission_queryer.readable_space_guids,
                  eager_loaded_associations: Presenters::V3::BuildPresenter.associated_resources)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::BuildPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/builds',
      message: message
    )
  end

  def create
    message = BuildCreateMessage.new(JSON.parse(request.body))
    unprocessable!(message.errors.full_messages) unless message.valid?

    package = PackageModel.where(guid: message.package_guid).
              eager(:app, :space, space: :organization, app: :buildpack_lifecycle_data).first
    unprocessable_package! unless package &&
      permission_queryer.can_manage_apps_in_active_space?(package.space.id) && permission_queryer.is_space_active?(package.space.id)

    FeatureFlag.raise_unless_enabled!(:diego_docker) if package.type == PackageModel::DOCKER_TYPE

    lifecycle = LifecycleProvider.provide(package, message)
    unprocessable!(lifecycle.errors.full_messages) unless lifecycle.valid?

    build = BuildCreate.new.create_and_stage(package: package, lifecycle: lifecycle, metadata: message.metadata)

    TelemetryLogger.v3_emit(
      'create-build',
      {
        'app-id' => package.app_guid,
        'build-id' => build.guid,
        'user-id' => current_user.guid,
      },
      {
        'lifecycle' => build.lifecycle_type,
        'buildpacks' => build.lifecycle_data&.buildpacks,
        'stack' => build.lifecycle_data.try(:stack),
      }
    )

    render status: :created, json: Presenters::V3::BuildPresenter.new(build)
  rescue BuildCreate::InvalidPackage => e
    bad_request!(e.message)
  rescue BuildCreate::MemorySpaceQuotaExceeded => e
    unprocessable!("space's memory limit exceeded: #{e.message}")
  rescue BuildCreate::MemoryOrgQuotaExceeded => e
    unprocessable!("organization's memory limit exceeded: #{e.message}")
  rescue BuildCreate::DiskLimitExceeded
    unprocessable!('disk limit exceeded')
  rescue BuildCreate::LogRateLimitSpaceQuotaExceeded => e
    unprocessable!("space's log rate limit exceeded: #{e.message}")
  rescue BuildCreate::LogRateLimitOrgQuotaExceeded => e
    unprocessable!("organization's log rate limit exceeded: #{e.message}")
  rescue BuildCreate::StagingInProgress
    raise CloudController::Errors::ApiError.new_from_details('StagingInProgress')
  rescue BuildCreate::BuildError => e
    unprocessable!(e.message)
  end

  def update
    build = BuildModel.find(guid: hashed_params[:guid])
    build_not_found! unless build.present?

    space = build.space
    build_not_found! unless can_read_build?(space)

    if hashed_params[:body].key?(:state)
      unauthorized! unless permission_queryer.can_update_build_state?
    else
      unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
      suspended! unless permission_queryer.is_space_active?(space.id)
    end

    build = BuildUpdate.new.update(build, create_valid_update_message)

    render status: :ok, json: Presenters::V3::BuildPresenter.new(build)
  end

  def show
    build = BuildModel.find(guid: hashed_params[:guid])

    build_not_found! unless build && permission_queryer.can_read_from_space?(build.app.space.id, build.app.space.organization_id)

    render status: :ok, json: Presenters::V3::BuildPresenter.new(build)
  end

  private

  def can_read_build?(space)
    permission_queryer.can_update_build_state? || permission_queryer.can_read_from_space?(space.id, space.organization_id)
  end

  def create_valid_update_message
    message = VCAP::CloudController::BuildUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?
    message
  end

  def build_not_found!
    resource_not_found!(:build)
  end

  def unprocessable_package!
    unprocessable!('Unable to use package. Ensure that the package exists and you have access to it.')
  end
end
