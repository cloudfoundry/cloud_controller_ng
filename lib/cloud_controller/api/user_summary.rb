module VCAP::CloudController
  rest_controller :UserSummary do
    disable_default_routes
    path_base "users"
    model_class_name :User

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::OrgManager
      read Permissions::OrgUser
      read Permissions::SpaceManager
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    def summary(id)
      user = find_id_and_validate_access(:read, id)
      orgs =  user.organizations

      Yajl::Encoder.encode(
        :guid => id,
        :organizations => orgs
      )
    end

    get "#{path_id}/summary", :summary
  end
end