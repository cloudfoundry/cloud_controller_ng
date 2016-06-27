require 'actions/organization_delete'
require 'queries/organization_user_roles_fetcher'

module VCAP::CloudController
  class OrganizationsController < RestController::ModelController
    def self.dependencies
      [:username_and_roles_populating_collection_renderer, :username_lookup_uaa_client, :services_event_repository]
    end

    def inject_dependencies(dependencies)
      super
      @user_roles_collection_renderer = dependencies.fetch(:username_and_roles_populating_collection_renderer)
      @username_lookup_uaa_client = dependencies.fetch(:username_lookup_uaa_client)
      @services_event_repository = dependencies.fetch(:services_event_repository)
    end

    define_attributes do
      attribute :name,            String
      attribute :billing_enabled, Message::Boolean, default: false
      attribute :status,          String, default: 'active'

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

    get '/v2/organizations/:guid/user_roles', :enumerate_user_roles
    def enumerate_user_roles(guid)
      logger.debug('cc.enumerate.related', guid: guid, association: 'user_roles')

      org = find_guid_and_validate_access(:read, guid)

      associated_controller = UsersController
      associated_path = "#{self.class.url_for_guid(guid)}/user_roles"
      opts = @opts.merge(transform_opts: { organization_id: org.id })

      @user_roles_collection_renderer.render_json(
        associated_controller,
        OrganizationUserRolesFetcher.new.fetch(org),
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
      [HTTP::OK, MultiJson.dump({ memory_usage_in_mb: OrganizationMemoryCalculator.get_memory_usage(org) })]
    end

    [:user, :manager, :billing_manager, :auditor].each do |role|
      plural_role = role.to_s.pluralize

      put "/v2/organizations/:guid/#{plural_role}", "add_#{role}_by_username".to_sym

      define_method("add_#{role}_by_username") do |guid|
        FeatureFlag.raise_unless_enabled!(:set_roles_by_username)

        username = parse_and_validate_json(body)['username']

        begin
          user_id = @username_lookup_uaa_client.id_for_username(username)
        rescue UaaUnavailable
          raise CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
        rescue UaaEndpointDisabled
          raise CloudController::Errors::ApiError.new_from_details('UaaEndpointDisabled')
        end
        raise CloudController::Errors::ApiError.new_from_details('UserNotFound', username) unless user_id

        user = User.where(guid: user_id).first || User.create(guid: user_id)

        org = find_guid_and_validate_access(:update, guid)
        org.send("add_#{role}", user)

        [HTTP::CREATED, object_renderer.render_json(self.class, org, @opts)]
      end
    end

    [:user, :manager, :billing_manager, :auditor].each do |role|
      plural_role = role.to_s.pluralize

      delete "/v2/organizations/:guid/#{plural_role}", "remove_#{role}_by_username".to_sym

      define_method("remove_#{role}_by_username") do |guid|
        FeatureFlag.raise_unless_enabled!(:unset_roles_by_username)

        username = parse_and_validate_json(body)['username']

        begin
          user_id = @username_lookup_uaa_client.id_for_username(username)
        rescue UaaUnavailable
          raise CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
        rescue UaaEndpointDisabled
          raise CloudController::Errors::ApiError.new_from_details('UaaEndpointDisabled')
        end
        raise CloudController::Errors::ApiError.new_from_details('UserNotFound', username) unless user_id

        user = User.where(guid: user_id).first

        raise CloudController::Errors::ApiError.new_from_details('UserNotFound', username) unless user

        org = find_guid_and_validate_access(:update, guid)
        org.send("remove_#{role}", user)

        [HTTP::NO_CONTENT]
      end
    end

    def delete(guid)
      org = find_guid_and_validate_access(:delete, guid)
      raise_if_has_dependent_associations!(org) if v2_api? && !recursive_delete?

      if !org.spaces.empty? && !recursive_delete?
        raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', 'spaces', Organization.table_name)
      end

      delete_action = OrganizationDelete.new(SpaceDelete.new(current_user.guid, current_user_email, @services_event_repository))
      deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(Organization, guid, delete_action)
      enqueue_deletion_job(deletion_job)
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

    def after_create(organization)
      return if SecurityContext.admin?
      organization.add_user(user)
      organization.add_manager(user)
    end
  end
end
