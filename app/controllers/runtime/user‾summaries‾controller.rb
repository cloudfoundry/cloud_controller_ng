require 'presenters/api/user_summary_presenter'

module VCAP::CloudController
  class UserSummariesController < RestController::ModelController
    path_base 'users'
    model_class_name :User

    get "#{path_guid}/summary", :summary
    def summary(guid)
      # Admins can see all users, non admins can only see themselves, see UserAccess.read?
      user = find_guid_and_validate_access(:read, guid)
      MultiJson.dump UserSummaryPresenter.new(user).to_hash
    end
  end
end
