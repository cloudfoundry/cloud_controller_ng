module VCAP::CloudController
  rest_controller :CrashEvent do
    permissions_required do
      read Permissions::CFAdmin
      read Permissions::OrgManager
      read Permissions::OrgUser
      read Permissions::SpaceManager
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      to_one    :app
      attribute :instance_guid, String
      attribute :instance_index, Integer
      attribute :exit_status, Integer
      attribute :timestamp, String
    end

    query_parameters :timestamp, :app_guid
  end
end