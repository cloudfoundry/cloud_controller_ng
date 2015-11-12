require 'messages/package_create_message'
require 'actions/package_create'
require 'actions/package_copy'

class AppsPackagesController < ApplicationController
  def create_new
    app_guid = params[:guid]

    message = PackageCreateMessage.create_from_http_request(app_guid, params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app_model = AppModel.where(guid: app_guid).eager(:space, space: :organization).all.first
    app_not_found! if app_model.nil? || !can_read?(app_model.space.guid, app_model.space.organization.guid)
    unauthorized! unless can_create?(app_model.space.guid)

    package = PackageCreate.new(current_user, current_user_email).create(message)

    render status: :created, json: PackagePresenter.new.present_json(package)
  rescue PackageCreate::InvalidPackage => e
    unprocessable!(e.message)
  end

  def index
    app_guid = params[:guid]
    message = PackagesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    app_model = AppModel.where(guid: app_guid).eager(:space, space: :organization).all.first
    app_not_found! if app_model.nil? || !can_read?(app_model.space.guid, app_model.space.organization.guid)

    paginated_result = SequelPaginator.new.get_page(app_model.packages_dataset.eager(:docker_data), pagination_options)

    render status: :ok, json: PackagePresenter.new.present_json_list(paginated_result, "/v3/apps/#{app_guid}/packages")
  end

  def create
    if params[:source_package_guid]
      create_copy
    else
      create_new
    end
  end

  def create_copy
    app_guid = params[:guid]
    source_package_guid = params[:source_package_guid]
    app_model = AppModel.where(guid: app_guid).eager(:space, space: :organization).all.first
    app_not_found! if app_model.nil? || !can_read?(app_model.space.guid, app_model.space.organization.guid)
    unauthorized! unless can_create?(app_model.space.guid)

    source_package = PackageModel.where(guid: source_package_guid).eager(:app, :space, space: :organization).eager(:docker_data).all.first

    package_not_found! if source_package.nil? || !can_read?(source_package.space.guid, source_package.space.organization.guid)
    unauthorized! unless can_create?(source_package.space.guid)
    unprocessable!('Source and destination app cannot be the same') if app_guid == source_package.app_guid

    package = PackageCopy.new.copy(app_guid, source_package)

    render status: :created, json: PackagePresenter.new.present_json(package)
  rescue PackageCopy::InvalidPackage => e
    unprocessable!(e.message)
  end

  private

  def membership
    @membership ||= VCAP::CloudController::Membership.new(current_user)
  end

  def can_read?(space_guid, org_guid)
    roles.admin? ||
    membership.has_any_roles?([Membership::SPACE_DEVELOPER,
                               Membership::SPACE_MANAGER,
                               Membership::SPACE_AUDITOR,
                               Membership::ORG_MANAGER], space_guid, org_guid)
  end

  def can_create?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end

  def app_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
  end

  def package_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Package not found')
  end
end
