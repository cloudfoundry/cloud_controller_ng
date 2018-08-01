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
          stager           = stagers.stager_for_app(app)
          droplets_to_stop = app.droplets_dataset.exclude(state: DropletModel::FINAL_STATES).all

          droplets_to_stop.each do |droplet|
            stager.stop_stage(droplet.guid)
          end
        end
      end
    end
  end
end
