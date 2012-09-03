# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :ServiceBinding do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::OrgManager
      create Permissions::SpaceDeveloper
      read   Permissions::SpaceDeveloper
      delete Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      to_one    :app
      to_one    :service_instance
    end

    query_parameters :app_guid, :service_instance_guid

    def create_quota_token_request(obj)
      ret = quota_token_request("post", obj)
      ret[:body][:audit_data] = obj.to_hash
      ret
    end

    def update_quota_token_request(obj)
      ret = quota_token_request("put", obj)
      ret[:body][:audit_data] = request_attrs
      ret
    end

    def delete_quota_token_request(obj)
       quota_token_request("delete", obj)
    end


    def self.translate_validation_exception(e, attributes)
      unique_errors = e.errors.on([:app_id, :service_instance_id])
      if unique_errors && unique_errors.include?(:unique)
        ServiceBindingAppServiceTaken.new(
          "#{attributes["app_guid"]} #{attributes["service_instance_guid"]}")
      else
        ServiceBindingInvalid.new(e.errors.full_messages)
      end
    end

    private

    # Tim might need to tweak this.  I'm not really sure what info the bizops
    # guys want here.
    def quota_token_request(op, obj)
      {
        :path => obj.app.space.organization_guid,
        :body => {
          :op                  => op,
          :user_id             => user.guid,
          :object              => "service_binding",
          :object_id           => obj.guid,
          :app_id              => obj.app.guid,
          :service_instance_id => obj.service_instance.guid
        }
      }
    end
  end
end
