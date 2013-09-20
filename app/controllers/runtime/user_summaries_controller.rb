require 'presenters/api/user_summary_presenter'

module VCAP::CloudController
  rest_controller :UserSummaries do
    disable_default_routes
    path_base "users"
    model_class_name :User

    def summary(guid)
      # only admins should have unfettered access to all users
      # UserAccess allows all to read so org and space user lists show all users in those lists
      raise Errors::NotAuthorized unless roles.admin?
      user = find_guid_and_validate_access(:read, guid)
      Yajl::Encoder.encode UserSummaryPresenter.new(user).to_hash
    end

    get "#{path_guid}/summary", :summary
  end
end
