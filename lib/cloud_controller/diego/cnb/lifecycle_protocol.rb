require 'cloud_controller/diego/buildpack_entry_generator'
require 'cloud_controller/diego/droplet_url_generator'
require 'cloud_controller/diego/lifecycle_protocol'
require 'cloud_controller/diego/cnb/lifecycle_data'
require 'cloud_controller/diego/cnb/staging_action_builder'
require 'cloud_controller/diego/buildpack/task_action_builder'

module VCAP
  module CloudController
    module Diego
      module CNB
        class LifecycleProtocol < VCAP::CloudController::Diego::LifecycleProtocolBase
          def staging_action_builder(config, staging_details)
            StagingActionBuilder.new(config, staging_details, lifecycle_data(staging_details))
          end

          def task_action_builder(config, task)
            VCAP::CloudController::Diego::Buildpack::TaskActionBuilder.new(config, task, task_lifecycle_data(task), 'root', ['--', task.command], 'cnb')
          end

          def desired_lrp_builder(config, process)
            DesiredLrpBuilder.new(config, builder_opts(process))
          end

          def new_lifecycle_data(staging_details)
            lifecycle_data = LifecycleData.new
            lifecycle_data.credentials = staging_details.lifecycle.credentials

            lifecycle_data
          end
        end
      end
    end
  end
end
