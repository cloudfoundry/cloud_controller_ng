require 'cloud_controller/presenters/user_summary_presenter'

module VCAP::CloudController
  rest_controller :UserSummaries do
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

    def summary(guid)
      user = find_guid_and_validate_access(:read, guid)
      Yajl::Encoder.encode UserSummaryPresenter.new(user).to_hash
    end

    get "#{path_guid}/summary", :summary
  end
end
