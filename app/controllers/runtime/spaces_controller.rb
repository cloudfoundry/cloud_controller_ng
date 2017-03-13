require 'actions/space_delete'
require 'fetchers/space_user_roles_fetcher'

module VCAP::CloudController
  class SpacesController < RestController::ModelController
    def self.dependencies
      [:space_event_repository, :username_and_roles_populating_collection_renderer, :uaa_client, :services_event_repository, :user_event_repository]
    end

    define_attributes do
      attribute :name, String
      attribute :allow_ssh, Message::Boolean, default: true
      attribute :isolation_segment_guid, String, default: nil, optional_in: [:create, :update]

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
      to_many :staging_security_groups
      to_one :space_quota_definition, optional_in: [:create], exclude_in: [:update]
    end

    query_parameters :name, :organization_guid, :developer_guid, :app_guid, :isolation_segment_guid
    sortable_parameters :id, :name

    deprecated_endpoint "#{path_guid}/domains"

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:organization_id, :name])
      if name_errors && name_errors.include?(:unique)
        CloudController::Errors::ApiError.new_from_details('SpaceNameTaken', attributes['name'])
      else
        CloudController::Errors::ApiError.new_from_details('SpaceInvalid', e.errors.full_messages)
      end
    end

    def inject_dependencies(dependencies)
      super
      @space_event_repository = dependencies.fetch(:space_event_repository)
      @user_event_repository = dependencies.fetch(:user_event_repository)
      @user_roles_collection_renderer = dependencies.fetch(:username_and_roles_populating_collection_renderer)
      @uaa_client = dependencies.fetch(:uaa_client)
      @services_event_repository = dependencies.fetch(:services_event_repository)
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

    def update(guid)
      json_msg = self.class::UpdateMessage.decode(body)
      @request_attrs = json_msg.extract(stringify_keys: true)
      logger.debug 'cc.update', guid: guid, attributes: redact_attributes(:update, request_attrs)
      raise InvalidRequest unless request_attrs

      space = find_guid(guid)

      before_update(space)

      current_role_guids = {}

      model.db.transaction do
        space.lock!

        current_role_guids = get_current_role_guids(space)

        validate_access(:read_for_update, space, request_attrs)
        space.update_from_hash(request_attrs)
        validate_access(:update, space, request_attrs)
      end

      generate_role_events_on_update(space, current_role_guids)
      after_update(space)

      [HTTP::CREATED, object_renderer.render_json(self.class, space, @opts)]
    end

    get '/v2/spaces/:guid/services', :enumerate_services
    def enumerate_services(guid)
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
        space.user_visible_relationship_dataset(relation_name, @access_context.user, @access_context.admin_override),
        ServiceInstancesController.query_parameters,
        @opts)
      service_instances.filter(space: space)

      collection_renderer.render_json(
        ServiceInstancesController,
        service_instances,
        "/v2/spaces/#{guid}/service_instances",
        @opts,
        params
      )
    end

    def delete(guid)
      space = find_guid_and_validate_access(:delete, guid)

      raise_if_has_dependent_associations!(space) unless recursive_delete?
      raise_if_dependency_present!(space) unless recursive_delete?

      @space_event_repository.record_space_delete_request(space, UserAuditInfo.from_context(SecurityContext), recursive_delete?)

      delete_action = SpaceDelete.new(UserAuditInfo.from_context(SecurityContext), @services_event_repository)
      deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(Space, guid, delete_action)
      enqueue_deletion_job(deletion_job)
    end

    [:manager, :developer, :auditor].each do |role|
      plural_role = role.to_s.pluralize

      put "/v2/spaces/:guid/#{plural_role}/:user_id", "add_#{role}_by_user_id".to_sym
      put "/v2/spaces/:guid/#{plural_role}", "add_#{role}_by_username".to_sym

      define_method("add_#{role}_by_username") do |guid|
        FeatureFlag.raise_unless_enabled!(:set_roles_by_username)

        username = parse_and_validate_json(body)['username']

        begin
          user_id = @uaa_client.id_for_username(username)
        rescue UaaUnavailable
          raise CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
        rescue UaaEndpointDisabled
          raise CloudController::Errors::ApiError.new_from_details('UaaEndpointDisabled')
        end
        raise CloudController::Errors::ApiError.new_from_details('UserNotFound', username) unless user_id

        add_role(guid, role, user_id, username)
      end

      define_method("add_#{role}_by_user_id") do |guid, user_id|
        username = @uaa_client.usernames_for_ids([user_id])[user_id]

        add_role(guid, role, user_id, username ? username : '')
      end
    end

    [:manager, :developer, :auditor].each do |role|
      plural_role = role.to_s.pluralize

      delete "/v2/spaces/:guid/#{plural_role}", "remove_#{role}_by_username".to_sym
      delete "/v2/spaces/:guid/#{plural_role}/:user_id", "remove_#{role}_by_user_id".to_sym

      define_method("remove_#{role}_by_username") do |guid|
        FeatureFlag.raise_unless_enabled!(:unset_roles_by_username)

        username = parse_and_validate_json(body)['username']

        begin
          user_id = @uaa_client.id_for_username(username)
        rescue UaaUnavailable
          raise CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
        rescue UaaEndpointDisabled
          raise CloudController::Errors::ApiError.new_from_details('UaaEndpointDisabled')
        end
        raise CloudController::Errors::ApiError.new_from_details('UserNotFound', username) unless user_id

        user = User.where(guid: user_id).first

        raise CloudController::Errors::ApiError.new_from_details('UserNotFound', username) unless user

        space = find_guid_and_validate_access(:update, guid)
        remove_role(space, role, user_id, username)

        [HTTP::OK, object_renderer.render_json(self.class, space, @opts)]
      end

      define_method("remove_#{role}_by_user_id") do |guid, user_id|
        space = if user_id == SecurityContext.current_user.guid
                  Space.first(guid: guid)
                else
                  find_guid_and_validate_access(:update, guid)
                end

        username = @uaa_client.usernames_for_ids([user_id])[user_id]
        remove_role(space, role, user_id, username ? username : '')

        [HTTP::NO_CONTENT, nil]
      end
    end

    delete '/v2/spaces/:guid/isolation_segment', :delete_isolation_segment
    def delete_isolation_segment(guid)
      space = find_guid(guid)
      check_org_update_access!(space)

      space.db.transaction do
        space.lock!
        space.update(isolation_segment_model: nil)
      end

      [HTTP::OK, object_renderer.render_json(self.class, space, @opts)]
    end

    def before_update(space)
      if request_attrs['isolation_segment_guid']
        check_org_update_access!(space)

        if IsolationSegmentModel.where(guid: request_attrs['isolation_segment_guid']).empty?
          raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', 'Isolation Segment not found')
        end
      end

      super(space)
    end

    private

    def add_role(guid, role, user_id, username)
      user = User.first(guid: user_id) || User.create(guid: user_id)

      user.username = username

      space = find_guid_and_validate_access(:update, guid)
      space.send("add_#{role}", user)

      @user_event_repository.record_space_role_add(space, user, role, UserAuditInfo.from_context(SecurityContext), request_attrs)

      [HTTP::CREATED, object_renderer.render_json(self.class, space, @opts)]
    end

    def remove_role(space, role, user_id, username)
      user = User.first(guid: user_id)
      raise CloudController::Errors::ApiError.new_from_details('InvalidRelation', "User with guid #{user_id} not found") unless user
      user.username = username

      space.send("remove_#{role}", user)

      @user_event_repository.record_space_role_remove(space, user, role, UserAuditInfo.from_context(SecurityContext), request_attrs)
    end

    def after_create(space)
      user_audit_info = UserAuditInfo.from_context(SecurityContext)

      @space_event_repository.record_space_create(space, user_audit_info, request_attrs)

      space.managers.each do |mgr|
        @user_event_repository.record_space_role_add(space, mgr, 'manager', user_audit_info, request_attrs)
      end

      space.auditors.each do |auditor|
        @user_event_repository.record_space_role_add(space, auditor, 'auditor', user_audit_info, request_attrs)
      end

      space.developers.each do |developer|
        @user_event_repository.record_space_role_add(space, developer, 'developer', user_audit_info, request_attrs)
      end
    end

    def after_update(space)
      @space_event_repository.record_space_update(space, UserAuditInfo.from_context(SecurityContext), request_attrs)
    end

    def raise_if_dependency_present!(space)
      if space.service_instances.present? || space.app_models.present? || space.service_brokers.present?
        raise CloudController::Errors::ApiError.new_from_details('NonrecursiveSpaceDeletionFailed', space.name)
      end
    end

    def check_org_update_access!(space)
      validate_access(:update, space.organization, nil)
    end

    define_messages
    define_routes

    def get_current_role_guids(space)
      current_role_guids = {}

      %w(developer manager auditor).each do |role|
        key = "#{role}_guids"

        if request_attrs[key]
          current_role_guids[role] = []
          space.send(role.pluralize.to_sym).each do |user|
            current_role_guids[role] << user.guid
          end
        end
      end

      current_role_guids
    end

    def generate_role_events_on_update(space, current_role_guids)
      user_audit_info = UserAuditInfo.from_context(SecurityContext)

      %w(manager auditor developer).each do |role|
        key = "#{role}_guids"

        user_guids_removed = []

        if request_attrs[key]
          user_guids_added = request_attrs[key]

          if current_role_guids[role]
            user_guids_added = request_attrs[key] - current_role_guids[role]
            user_guids_removed = current_role_guids[role] - request_attrs[key]
          end

          user_guids_added.each do |user_id|
            user = User.first(guid: user_id) || User.create(guid: user_id)
            user.username = '' unless user.username

            @user_event_repository.record_space_role_add(
              space,
                user,
                role,
                user_audit_info,
                request_attrs
            )
          end

          user_guids_removed.each do |user_id|
            user = User.first(guid: user_id)
            user.username = '' unless user.username

            @user_event_repository.record_space_role_remove(
              space,
                user,
                role,
                user_audit_info,
                request_attrs
            )
          end
        end
      end
    end
  end
end
