module VCAP::CloudController
  class AppSecurityGroupController < RestController::BaseController
    allow_unauthenticated_access
    get '/internal/v4/asg_latest_update', :return_asg_latest_update
    def return_asg_latest_update
      [HTTP::OK, MultiJson.dump({ last_update: AsgLatestUpdate.last_update }, pretty: true)]
    end
  end
end
