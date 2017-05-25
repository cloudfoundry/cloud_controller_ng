require 'actions/organization_delete'
require 'fetchers/organization_user_roles_fetcher'

module VCAP::CloudController
  class OrganizationsController < RestController::ModelController
    def self.dependencies
      [
        :username_and_roles_populating_collection_renderer,
        :uaa_client,
        :services_event_repository,
        :user_event_repository,
        :organization_event_repository
      ]
    end

    def inject_dependencies(dependencies)
      super
      @user_roles_collection_renderer = dependencies.fetch(:username_and_roles_populating_collection_renderer)
      @uaa_client = dependencies.fetch(:uaa_client)
      @services_event_repository = dependencies.fetch(:services_event_repository)
      @user_event_repository = dependencies.fetch(:user_event_repository)
      @organization_event_repository = dependencies.fetch(:organization_event_repository)
    end

    define_attributes do
      attribute :name,            String
      attribute :billing_enabled, Message::Boolean, default: false
      attribute :status,          String, default: 'active'
      attribute :default_isolation_segment_guid, String, default: nil, exclude_in: :create, optional_in: :update

      to_one :quota_definition, optional_in: :create
      to_many :spaces,           exclude_in: :create
      to_many :domains,          exclude_in: [:create, :update], route_for: [:get, :delete]
      to_many :private_domains,  exclude_in: [:create, :update]
      to_many :users
      to_many :managers
      to_many :billing_managers
      to_many :auditors
      to_many :app_events, link_only: true
      to_many :space_quota_definitions, exclude_in: :create
    end

    query_parameters :name, :space_guid, :user_guid,
      :manager_guid, :billing_manager_guid,
      :auditor_guid, :status
    sortable_parameters :id, :name

    deprecated_endpoint "#{path_guid}/domains"

    def self.translate_validation_exception(e, attributes)
      quota_def_errors = e.errors.on(:quota_definition_id)
      name_errors = e.errors.on(:name)
      if quota_def_errors && quota_def_errors.include?(:not_authorized)
        CloudController::Errors::ApiError.new_from_details('NotAuthorized', attributes['quota_definition_id'])
      elsif name_errors && name_errors.include?(:unique)
        CloudController::Errors::ApiError.new_from_details('OrganizationNameTaken', attributes['name'])
      else
        CloudController::Errors::ApiError.new_from_details('OrganizationInvalid', e.errors.full_messages)
      end
    end

    def before_update(org)
      if request_attrs['default_isolation_segment_guid']
        unless IsolationSegmentModel.first(guid: request_attrs['default_isolation_segment_guid'])
          raise CloudController::Errors::ApiError.new_from_details(
            'ResourceNotFound',
            'Could not find Isolation Segment to set as the default.')
        end
      end

      super(org)
    end

    def update(guid)
      json_msg = self.class::UpdateMessage.decode(body)
      @request_attrs = json_msg.extract(stringify_keys: true)
      logger.debug 'cc.update', guid: guid, attributes: redact_attributes(:update, request_attrs)
      raise InvalidRequest unless request_attrs

      org = find_guid(guid)

      before_update(org)

      current_role_guids = {}

      model.db.transaction do
        org.lock!

        current_role_guids = get_current_role_guids(org)

        validate_access(:read_for_update, org, request_attrs)
        org.update_from_hash(request_attrs)
        validate_access(:update, org, request_attrs)
      end

      generate_role_events_on_update(org, current_role_guids)
      after_update(org)

      [HTTP::CREATED, object_renderer.render_json(self.class, org, @opts)]
    end

    get '/v2/organizations/:guid/user_roles', :enumerate_user_roles
    def enumerate_user_roles(guid)
      logger.debug('cc.enumerate.related', guid: guid, association: 'user_roles')

      org = find_guid_and_validate_access(:read, guid)

      associated_controller = UsersController
      associated_path = "#{self.class.url_for_guid(guid)}/user_roles"
      opts = @opts.merge(transform_opts: { organization_id: org.id })

      @user_roles_collection_renderer.render_json(
        associated_controller,
        OrganizationUserRolesFetcher.fetch(org, user_guid: user_guid_parameter),
        associated_path,
        opts,
        {},
      )
    end

    get '/v2/organizations/:guid/services', :enumerate_services
    def enumerate_services(guid)
      org = find_guid_and_validate_access(:read, guid)

      associated_controller = ServicesController
      associated_model = Service

      filtered_dataset = Query.filtered_dataset_from_query_params(
        associated_model,
        associated_model.organization_visible(org),
        associated_controller.query_parameters,
        @opts,
      )

      associated_path = "#{self.class.url_for_guid(guid)}/services"

      opts = @opts.merge(
        additional_visibility_filters: {
          service_plans: proc { |ds| ds.organization_visible(org) },
        }
      )

      collection_renderer.render_json(
        associated_controller,
        filtered_dataset,
        associated_path,
        opts,
        {},
      )
    end

    get '/v2/organizations/:guid/instance_usage', :get_instance_usage
    def get_instance_usage(guid)
      org = find_guid_and_validate_access(:read, guid)
      response = { instance_usage: OrganizationInstanceUsageCalculator.get_instance_usage(org) }
      [HTTP::OK, MultiJson.dump(response)]
    end

    get '/v2/organizations/:guid/memory_usage', :get_memory_usage
    def get_memory_usage(guid)
      org = find_guid_and_validate_access(:read, guid)
      [HTTP::OK, MultiJson.dump({ memory_usage_in_mb: org.memory_used })]
    end

    [:user, :manager, :billing_manager, :auditor].each do |role|
      plural_role = role.to_s.pluralize

      put "/v2/organizations/:guid/#{plural_role}/:user_id", "add_#{role}_by_user_id".to_sym
      put "/v2/organizations/:guid/#{plural_role}", "add_#{role}_by_username".to_sym

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
        add_role(guid, role, user_id, '')
      end
    end

    [:user, :manager, :billing_manager, :auditor].each do |role|
      plural_role = role.to_s.pluralize

      delete "/v2/organizations/:guid/#{plural_role}/:user_id", "remove_#{role}_by_user_id".to_sym
      delete "/v2/organizations/:guid/#{plural_role}", "remove_#{role}_by_username".to_sym

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

        org = find_guid_and_validate_access(:update, guid)

        if recursive_delete? && role == :user
          org.send("remove_#{role}_recursive", user)
        else
          org.send("remove_#{role}", user)
        end

        @user_event_repository.record_organization_role_remove(
          org,
          user,
          role,
          UserAuditInfo.from_context(SecurityContext),
          request_attrs
        )

        [HTTP::NO_CONTENT]
      end

      define_method("remove_#{role}_by_user_id") do |guid, user_id|
        response = remove_related(guid, "#{role}s".to_sym, user_id, Organization)

        user = User.first(guid: user_id)
        user.username = '' unless user.username

        @user_event_repository.record_organization_role_remove(
          Organization.first(guid: guid),
          user,
          role.to_s,
          UserAuditInfo.from_context(SecurityContext),
          {}
        )

        response
      end
    end

    def delete(guid)
      org = find_guid_and_validate_access(:delete, guid)
      raise_if_has_dependent_associations!(org) if v2_api? && !recursive_delete?

      if !org.spaces.empty? && !recursive_delete?
        raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', 'spaces', Organization.table_name)
      end

      delete_action = OrganizationDelete.new(SpaceDelete.new(UserAuditInfo.from_context(SecurityContext), @services_event_repository))
      deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(Organization, guid, delete_action)
      response = enqueue_deletion_job(deletion_job)

      @organization_event_repository.record_organization_delete_request(org, UserAuditInfo.from_context(SecurityContext), request_attrs)

      response
    end

    def remove_related(guid, name, other_guid, find_model=model)
      model.db.transaction do
        if recursive_delete? && name.to_s.eql?('users')
          org = find_guid(guid, model)
          validate_access(:can_remove_related_object, org, { relation: name, related_guid: other_guid })
          user = User.find(guid: other_guid)

          org.remove_user_recursive(user)
        end

        super(guid, name, other_guid, find_model)
      end
    end

    delete '/v2/organizations/:guid/default_isolation_segment', :delete_default_isolation_segment
    def delete_default_isolation_segment(guid)
      org = find_guid_and_validate_access(:update, guid)
      validate_access(:update, org, nil)

      org.db.transaction do
        org.lock!
        org.update(default_isolation_segment_guid: nil)
      end

      [HTTP::OK, object_renderer.render_json(self.class, org, @opts)]
    end

    put '/v2/organizations/:guid/private_domains/:domain_guid', :share_domain
    def share_domain(guid, domain_guid)
      org = find_guid_and_validate_access(:update, guid)
      domain = find_guid_and_validate_access(:update, domain_guid, PrivateDomain)

      org.add_private_domain(domain)
      @opts.merge(transform_opts: { organization_id: org.id })
      [HTTP::CREATED, object_renderer.render_json(self.class, org, @opts)]
    end

    delete "#{path_guid}/domains/:domain_guid" do |controller_instance|
      controller_instance.add_warning('Endpoint removed')
      headers = { 'Location' => '/v2/private_domains/:domain_guid' }
      [HTTP::MOVED_PERMANENTLY, headers, 'Use DELETE /v2/private_domains/:domain_guid']
    end

    define_messages
    define_routes

    private

    def add_role(guid, role, user_id, username)
      user = User.first(guid: user_id) || User.create(guid: user_id)

      user.username = username

      org = find_guid_and_validate_access(:update, guid)
      org.send("add_#{role}", user)

      @user_event_repository.record_organization_role_add(org, user, role, UserAuditInfo.from_context(SecurityContext), request_attrs)

      [HTTP::CREATED, object_renderer.render_json(self.class, org, @opts)]
    end

    def user_guid_parameter
      @opts[:q][0].split(':')[1] if @opts[:q]
    end

    def after_create(organization)
      user_audit_info = UserAuditInfo.from_context(SecurityContext)

      @organization_event_repository.record_organization_create(organization, user_audit_info, request_attrs)
      unless SecurityContext.admin?
        organization.add_user(user)
        organization.add_manager(user)
      end

      organization.users.each do |user|
        @user_event_repository.record_organization_role_add(organization, user, 'user', user_audit_info, request_attrs)
      end

      organization.auditors.each do |auditor|
        @user_event_repository.record_organization_role_add(organization, auditor, 'auditor', user_audit_info, request_attrs)
      end

      organization.billing_managers.each do |billing_manager|
        @user_event_repository.record_organization_role_add(organization, billing_manager, 'billing_manager', user_audit_info, request_attrs)
      end

      organization.managers.each do |manager|
        @user_event_repository.record_organization_role_add(organization, manager, 'manager', user_audit_info, request_attrs)
      end
    end

    def after_update(organization)
      @organization_event_repository.record_organization_update(organization, UserAuditInfo.from_context(SecurityContext), request_attrs)
      super(organization)
    end

    def get_current_role_guids(org)
      current_role_guids = {}

      %w(user manager billing_manager auditor).each do |role|
        key = "#{role}_guids"

        if request_attrs[key]
          current_role_guids[role] = []
          org.send(role.pluralize.to_sym).each do |user|
            current_role_guids[role] << user.guid
          end
        end
      end

      current_role_guids
    end

    def generate_role_events_on_update(organization, current_role_guids)
      user_audit_info = UserAuditInfo.from_context(SecurityContext)

      %w(manager auditor user billing_manager).each do |role|
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

            @user_event_repository.record_organization_role_add(
              organization,
                user,
                role,
                user_audit_info,
                request_attrs
            )
          end

          user_guids_removed.each do |user_id|
            user = User.first(guid: user_id)
            user.username = '' unless user.username

            @user_event_repository.record_organization_role_remove(
              organization,
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
