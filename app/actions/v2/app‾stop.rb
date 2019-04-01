module VCAP::CloudController
  module V2
    class AppStop
      class << self
        def stop(app, cancel_action)
          VCAP::CloudController::AppStop.stop_without_event(app)

          cancel_action.cancel(app.builds_dataset.all)
        end
      end
    end
  end
end
