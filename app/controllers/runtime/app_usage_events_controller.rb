module VCAP::CloudController
  class AppUsageEventsController < RestController::ModelController
    get "/v2/app_usage_events", :enumerate
  end
end
