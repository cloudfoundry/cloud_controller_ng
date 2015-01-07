require 'presenters/api/user_summary_presenter'

module VCAP::CloudController
  class UserSummariesController < RestController::ModelController
    path_base 'users'
    model_class_name :User

    get "#{path_guid}/summary", :summary
    def summary(guid)
      # only admins should have unfettered access to all users
      # UserAccess allows all to read so org and space user lists show all users in those lists
      raise Errors::ApiError.new_from_details('NotAuthorized') unless roles.admin?
      user = find_guid_and_validate_access(:read, guid)
      MultiJson.dump UserSummaryPresenter.new(user).to_hash
    end
  end
end
