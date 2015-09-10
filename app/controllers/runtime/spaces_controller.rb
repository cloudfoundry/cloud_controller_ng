require 'actions/space_delete'
require 'queries/space_user_roles_fetcher'

module VCAP::CloudController
  class SpacesController < RestController::ModelController
    def self.dependencies
      [:space_event_repository, :username_and_roles_populating_collection_renderer, :username_lookup_uaa_client]
    end

    define_attributes do
      attribute :name, String
      attribute :allow_ssh, Message::Boolean, default: true

      to_one :organization
      to_many :developers
      to_many :managers
      to_many :auditors
      to_many :apps,                    exclude_in: [:create, :update], route_for: :get
      to_many :routes,                  exclude_in: [:create, :update], route_for: :get
      to_many :domains
      to_many :service_instances,       route_for: :get
      to_many :app_events,              link_only: true, exclude_in: [:create, :update], route_for: :get
      to_many :events,                  link_only: true, exclude_in: [:create, :update], route_for: :get
      to_many :security_groups
      to_one :space_quota_definition,  optional_in: [:create], exclude_in: [:update]
    end

    query_parameters :name, :organization_guid, :developer_guid, :app_guid

    deprecated_endpoint "#{path_guid}/domains"

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:organization_id, :name])
      if name_errors && name_errors.include?(:unique)
        Errors::ApiError.new_from_details('SpaceNameTaken', attributes['name'])
      else
        Errors::ApiError.new_from_details('SpaceInvalid', e.errors.full_messages)
      end
    end

    def inject_dependencies(dependencies)
      super
      @space_event_repository = dependencies.fetch(:space_event_repository)
      @user_roles_collection_renderer = dependencies.fetch(:username_and_roles_populating_collection_renderer)
      @username_lookup_uaa_client = dependencies.fetch(:username_lookup_uaa_client)
    end

    get '/v2/spaces/:guid/user_roles', :enumerate_user_roles
    def enumerate_user_roles(guid)
      logger.debug('cc.enumerate.related', guid: guid, association: 'user_roles')

      space = find_guid_and_validate_access(:read, guid)

      associated_controller = UsersController
      associated_path = "#{self.class.url_for_guid(guid)}/user_roles"
      opts = @opts.merge(transform_opts: { space_id: space.id })

      @user_roles_collection_renderer.render_json(
        associated_controller,
        SpaceUserRolesFetcher.new.fetch(space),
        associated_path,
        opts,
        {},
      )
    end

    get '/v2/spaces/:guid/services', :enumerate_services
    def enumerate_services(guid)
      logger.debug 'cc.enumerate.related', guid: guid, association: 'services'

      space = find_guid_and_validate_access(:read, guid)

      filtered_dataset = Query.filtered_dataset_from_query_params(
        Service,
        Service.space_or_org_visible_for_user(space, SecurityContext.current_user),
        ServicesController.query_parameters,
        @opts,
      )

      associated_path = "#{self.class.url_for_guid(guid)}/services"

      opts = @opts.merge(
        additional_visibility_filters: {
          service_plans: proc { |ds| ds.organization_visible(space.organization) },
        }
      )

      collection_renderer.render_json(
        ServicesController,
        filtered_dataset,
        associated_path,
        opts,
        {},
      )
    end

    get '/v2/spaces/:guid/service_instances', :enumerate_service_instances
    def enumerate_service_instances(guid)
      space = find_guid_and_validate_access(:read, guid)

      if params['return_user_provided_service_instances'] == 'true'
        model_class = ServiceInstance
        relation_name = :service_instances
      else
        model_class = ManagedServiceInstance
        relation_name = :managed_service_instances
      end

      service_instances = Query.filtered_dataset_from_query_params(
        model_class,
        space.user_visible_relationship_dataset(relation_name, SecurityContext.current_user, SecurityContext.admin?),
        ServiceInstancesController.query_parameters,
        @opts)
      service_instances.filter(space: space)

      collection_renderer.render_json(
        ServiceInstancesController,
        service_instances,
        "/v2/spaces/#{guid}/service_instances",
        @opts,
        {}
      )
    end

    def delete(guid)
      space = find_guid_and_validate_access(:delete, guid)
      raise_if_has_associations!(space) if v2_api? && !recursive?

      if !space.app_models.empty? && !recursive?
        raise VCAP::Errors::ApiError.new_from_details('AssociationNotEmpty', 'app_model', Space.table_name)
      end

      if !space.service_instances.empty? && !recursive?
        raise VCAP::Errors::ApiError.new_from_details('AssociationNotEmpty', 'service_instances', Space.table_name)
      end

      @space_event_repository.record_space_delete_request(space, SecurityContext.current_user, SecurityContext.current_user_email, recursive?)

      delete_action = SpaceDelete.new(current_user.guid, current_user_email)
      deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(Space, guid, delete_action)
      enqueue_deletion_job(deletion_job)
    end

    [:manager, :developer, :auditor].each do |role|
      plural_role = role.to_s.pluralize

      put "/v2/spaces/:guid/#{plural_role}", "add_#{role}_by_username".to_sym

      define_method("add_#{role}_by_username") do |guid|
        FeatureFlag.raise_unless_enabled!('set_roles_by_username') unless SecurityContext.admin?

        username = parse_and_validate_json(body)['username']

        begin
          user_id = @username_lookup_uaa_client.id_for_username(username)
        rescue UaaUnavailable
          raise VCAP::Errors::ApiError.new_from_details('UaaUnavailable')
        rescue UaaEndpointDisabled
          raise VCAP::Errors::ApiError.new_from_details('UaaEndpointDisabled')
        end
        raise VCAP::Errors::ApiError.new_from_details('UserNotFound', username) unless user_id

        user = User.where(guid: user_id).first || User.create(guid: user_id)

        space = find_guid_and_validate_access(:update, guid)
        space.send("add_#{role}", user)

        [HTTP::CREATED, object_renderer.render_json(self.class, space, @opts)]
      end
    end

    [:manager, :developer, :auditor].each do |role|
      plural_role = role.to_s.pluralize

      delete "/v2/spaces/:guid/#{plural_role}", "remove_#{role}_by_username".to_sym

      define_method("remove_#{role}_by_username") do |guid|
        FeatureFlag.raise_unless_enabled!('unset_roles_by_username') unless SecurityContext.admin?

        username = parse_and_validate_json(body)['username']

        begin
          user_id = @username_lookup_uaa_client.id_for_username(username)
        rescue UaaUnavailable
          raise VCAP::Errors::ApiError.new_from_details('UaaUnavailable')
        rescue UaaEndpointDisabled
          raise VCAP::Errors::ApiError.new_from_details('UaaEndpointDisabled')
        end
        raise VCAP::Errors::ApiError.new_from_details('UserNotFound', username) unless user_id

        user = User.where(guid: user_id).first

        raise VCAP::Errors::ApiError.new_from_details('UserNotFound', username) unless user

        space = find_guid_and_validate_access(:update, guid)
        space.send("remove_#{role}", user)

        [HTTP::OK, object_renderer.render_json(self.class, space, @opts)]
      end
    end

    private

    def after_create(space)
      @space_event_repository.record_space_create(space, SecurityContext.current_user, SecurityContext.current_user_email, request_attrs)
    end

    def after_update(space)
      @space_event_repository.record_space_update(space, SecurityContext.current_user, SecurityContext.current_user_email, request_attrs)
    end

    define_messages
    define_routes
  end
end
