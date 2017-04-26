module VCAP::CloudController
  module V2
    class AppStop
      class << self
        def stop(app, stagers)
          VCAP::CloudController::AppStop.stop_without_event(app)
          abort_staging!(stagers, app)
        end

        private

        def abort_staging!(stagers, app)
          stager = stagers.stager_for_app(app)
          builds_to_stop = app.builds_dataset.exclude(state: BuildModel::FINAL_STATES).all

          builds_to_stop.each do |build|
            stager.stop_stage(build.guid)
          end
        end
      end
    end
  end
end
