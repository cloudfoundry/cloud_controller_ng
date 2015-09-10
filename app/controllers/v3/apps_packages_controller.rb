require 'presenters/v3/package_presenter'
require 'cloud_controller/paging/pagination_options'
require 'messages/package_create_message'
require 'actions/package_create'
require 'actions/package_copy'

module VCAP::CloudController
  class AppsPackagesController < RestController::BaseController
    def self.dependencies
      [:package_presenter]
    end

    def inject_dependencies(dependencies)
      @package_presenter = dependencies[:package_presenter]
    end

    get '/v3/apps/:guid/packages', :list_packages
    def list_packages(guid)
      check_read_permissions!

      pagination_options = PaginationOptions.from_params(params)
      invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?
      invalid_param!("Unknown query param(s) '#{params.keys.join("', '")}'") if params.any?

      app = AppModel.where(guid: guid).eager(:space, space: :organization).all.first
      app_not_found! if app.nil? || !can_read?(app.space.guid, app.space.organization.guid)

      paginated_result = SequelPaginator.new.get_page(app.packages_dataset, pagination_options)

      [HTTP::OK, @package_presenter.present_json_list(paginated_result, "/v3/apps/#{guid}/packages")]
    end

    post '/v3/apps/:guid/packages', :create
    def create(app_guid)
      if params['source_package_guid']
        create_copy(app_guid)
      else
        create_new(app_guid)
      end
    end

    def create_copy(app_guid)
      check_write_permissions!

      app = AppModel.where(guid: app_guid).eager(:space, space: :organization).all.first
      app_not_found! if app.nil? || !can_read?(app.space.guid, app.space.organization.guid)
      unauthorized! unless can_create?(app.space.guid)

      source_package = PackageModel.where(guid: params['source_package_guid']).eager(:app, :space, space: :organization).all.first
      package_not_found! if source_package.nil? || !can_read?(source_package.space.guid, source_package.space.organization.guid)
      unauthorized! unless can_create?(source_package.space.guid)

      unprocessable!('Source and destination app cannot be the same') if app_guid == source_package.app_guid

      package = PackageCopy.new.copy(app_guid, source_package)

      [HTTP::CREATED, @package_presenter.present_json(package)]
    rescue PackageCopy::InvalidPackage => e
      unprocessable!(e.message)
    end

    def create_new(app_guid)
      check_write_permissions!

      request = parse_and_validate_json(body)
      message = PackageCreateMessage.create_from_http_request(app_guid, request)
      unprocessable!(message.errors.full_messages) unless message.valid?

      app = AppModel.where(guid: app_guid).eager(:space, space: :organization).all.first
      app_not_found! if app.nil? || !can_read?(app.space.guid, app.space.organization.guid)
      unauthorized! unless can_create?(app.space.guid)

      package = PackageCreate.new(current_user, current_user_email).create(message)

      [HTTP::CREATED, @package_presenter.present_json(package)]
    rescue PackageCreate::InvalidPackage => e
      unprocessable!(e.message)
    end

    private

    def membership
      @membership ||= Membership.new(current_user)
    end

    def can_read?(space_guid, org_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER,
                                 Membership::SPACE_MANAGER,
                                 Membership::SPACE_AUDITOR,
                                 Membership::ORG_MANAGER], space_guid, org_guid)
    end

    def can_create?(space_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
    end

    def app_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
    end

    def package_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Package not found')
    end

    def unprocessable!(message)
      raise VCAP::Errors::ApiError.new_from_details('UnprocessableEntity', message)
    end

    def unauthorized!
      raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
    end
  end
end
