require 'services/api'

module VCAP::CloudController
  
  rest_controller :ManagedServiceInstance do
    permissions_required do
      #read Permissions::CFAdmin
      #read Permissions::OrgManager
      #read Permissions::SpaceDeveloper
      #read Permissions::SpaceAuditor
    end

    define_attributes do
      #attribute :name,  String
      #to_one    :space
      #to_one    :service_plan
      #to_many   :service_bindings
      #attribute :dashboard_url, String, exclude_in: [:create, :update]
    end

    #query_parameters(
    #  :name,
    #  :space_guid,
    #  :service_plan_guid,
    #  :service_binding_guid,
    #)
  end
end
