module VCAP::CloudController
  class OrganizationsController < RestController::ModelController
    define_attributes do
      attribute :name, String
      attribute :billing_enabled, Message::Boolean, :default => false
      attribute :status, String, default: 'active'
      to_one    :quota_definition, optional_in: :create
      to_many   :spaces, exclude_in: :create
      to_many   :domains, :exclude_in => :delete
      to_many   :private_domains
      to_many   :users
      to_many   :managers
      to_many   :billing_managers
      to_many   :auditors
      to_many   :app_events, :link_only => true
    end

    query_parameters :name, :space_guid, :user_guid,
                    :manager_guid, :billing_manager_guid,
                    :auditor_guid, :status

    deprecated_endpoint "#{path_guid}/domains/*"

    def self.translate_validation_exception(e, attributes)
      quota_def_errors = e.errors.on(:quota_definition_id)
      name_errors = e.errors.on(:name)
      if quota_def_errors && quota_def_errors.include?(:not_authorized)
        Errors::NotAuthorized.new(attributes["quota_definition_id"])
      elsif name_errors && name_errors.include?(:unique)
        Errors::OrganizationNameTaken.new(attributes["name"])
      else
        Errors::OrganizationInvalid.new(e.errors.full_messages)
      end
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    delete "#{path_guid}/domains/:domain_guid" do |_|
      headers = {"X-Cf-Warning" => "Endpoint removed", "Location" => "/v2/private_domains/:domain_guid"}
      [HTTP::MOVED_PERMANENTLY, headers, "Use DELETE /v2/private_domains/:domain_guid"]
    end

    define_messages
    define_routes
  end
end
