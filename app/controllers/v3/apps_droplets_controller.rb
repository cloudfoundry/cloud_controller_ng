require 'queries/app_droplets_list_fetcher'

module VCAP::CloudController
  class AppsDropletsController < RestController::BaseController
    class InvalidParam < StandardError; end

    def self.dependencies
      [:droplet_presenter]
    end

    def inject_dependencies(dependencies)
      @droplet_presenter = dependencies[:droplet_presenter]
    end

    get '/v3/apps/:guid/droplets', :list
    def list(app_guid)
      check_read_permissions!
      validate_allowed_params(params)

      pagination_options = PaginationOptions.from_params(params)
      invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

      app, space, org = AppFetcher.new.fetch(app_guid)
      app_not_found! if app.nil?

      if membership.admin? || can_read?(space.guid, org.guid)
        paginated_result = AppDropletsListFetcher.new.fetch(app_guid, pagination_options, params)
      else
        app_not_found!
      end

      [HTTP::OK, @droplet_presenter.present_json_list(paginated_result, "/v3/apps/#{app_guid}/droplets", params)]
    rescue InvalidParam => e
      invalid_param!(e.message)
    end

    def membership
      @membership ||= Membership.new(current_user)
    end

    private

    def can_read?(space_guid, org_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER,
                                 Membership::SPACE_MANAGER,
                                 Membership::SPACE_AUDITOR,
                                 Membership::ORG_MANAGER], space_guid, org_guid)
    end

    def app_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
    end

    def validate_allowed_params(params)
      schema = {
        'states' => ->(v) { v.is_a? Array },
        'page' => ->(v) { v.to_i > 0 },
        'per_page' => ->(v) { v.to_i > 0 },
        'order_by' => ->(v) { %w(created_at updated_at).include?(v) },
        'order_direction' => ->(v) { %w(asc desc).include?(v) }
      }
      params.each do |key, value|
        validator = schema[key]
        raise InvalidParam.new("Unknown query param #{key}") if validator.nil?
        raise InvalidParam.new("Invalid type for param #{key}") if !validator.call(value)
      end
    end
  end
end
