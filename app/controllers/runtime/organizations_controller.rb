module VCAP::CloudController
  class OrganizationsController < RestController::ModelController
    define_attributes do
      attribute :name, String
      attribute :billing_enabled, Message::Boolean, :default => false
      attribute :status, String, default: 'active'
      to_one    :quota_definition, optional_in: :create
      to_many   :spaces, exclude_in: :create
      to_many   :domains
      to_many   :private_domains
      to_many   :users
      to_many   :managers
      to_many   :billing_managers
      to_many   :auditors
      to_many   :app_events, :link_only => true
      to_many   :space_quota_definitions, exclude_in: :create
    end

    query_parameters :name, :space_guid, :user_guid,
      :manager_guid, :billing_manager_guid,
      :auditor_guid, :status

    deprecated_endpoint "#{path_guid}/domains"

    def self.translate_validation_exception(e, attributes)
      quota_def_errors = e.errors.on(:quota_definition_id)
      name_errors = e.errors.on(:name)
      if quota_def_errors && quota_def_errors.include?(:not_authorized)
        Errors::ApiError.new_from_details("NotAuthorized", attributes["quota_definition_id"])
      elsif name_errors && name_errors.include?(:unique)
        Errors::ApiError.new_from_details("OrganizationNameTaken", attributes["name"])
      else
        Errors::ApiError.new_from_details("OrganizationInvalid", e.errors.full_messages)
      end
    end

    get "/v2/organizations/:guid/services", :enumerate_services
    def enumerate_services(guid)
      logger.debug "cc.enumerate.related", guid: guid, association: "services"

      org = find_guid_and_validate_access(:read, guid)

      associated_controller, associated_model = ServicesController, Service

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

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    def remove_related(guid, name, other_guid)
      model.db.transaction do
        if recursive? && name.to_s.eql?("users")
          org = find_guid_and_validate_access(:update, guid)
          user = User.find(:guid => other_guid)

          org.remove_user_recursive(user)
        end

        super(guid, name, other_guid)
      end
    end

    delete "#{path_guid}/domains/:domain_guid" do |controller_instance|
      controller_instance.add_warning("Endpoint removed")
      headers = {"Location" => "/v2/private_domains/:domain_guid"}
      [HTTP::MOVED_PERMANENTLY, headers, "Use DELETE /v2/private_domains/:domain_guid"]
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
