# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Organization do
    permissions_required do
      full Permissions::CFAdmin
      full Permissions::OrgManager
      read Permissions::OrgUser
      read Permissions::BillingManager
    end

    define_attributes do
      attribute :name, String
      to_many   :users
      to_many   :app_spaces, :exclude_in => :create
      to_many   :managers
      to_many   :billing_managers
    end

    query_parameters :name, :user_guid, :app_space_guid

    def enumeration_filter
      { :managers => [@user],
        :users => [@user],
        :billing_managers => [@user]
      }.sql_or
    end

    def update_quota_token_request(org)
      # TODO: sync payload with ilia
      {
        :path => "/quota/#{org.guid}",
        :body => {
          :user_id      => @user.id,
          :object       => "org",
          :object_id    => org.guid,
          :object_name  => request_attrs["name"],
          :audit_data   => request_attrs
        }
      }
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        OrganizationNameTaken.new(attributes["name"])
      else
        OrganizationInvalid.new(e.errors.full_messages)
      end
    end
  end
end
