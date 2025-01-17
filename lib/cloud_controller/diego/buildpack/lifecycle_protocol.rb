require 'cloud_controller/diego/droplet_url_generator'
require 'cloud_controller/diego/lifecycle_protocol'
require 'cloud_controller/diego/buildpack/lifecycle_data'
require 'cloud_controller/diego/buildpack/staging_action_builder'

module VCAP
  module CloudController
    module Diego
      module Buildpack
        class LifecycleProtocol < VCAP::CloudController::Diego::LifecycleProtocolBase
          def staging_action_builder(config, staging_details)
            StagingActionBuilder.new(config, staging_details, lifecycle_data(staging_details))
          end

          def task_action_builder(config, task)
            TaskActionBuilder.new(config, task, task_lifecycle_data(task), 'vcap', ['app', task.command, ''], 'buildpack')
          end

          def desired_lrp_builder(config, process)
            DesiredLrpBuilder.new(config, builder_opts(process))
          end

          def new_lifecycle_data(_)
            LifecycleData.new
          end

          def type
            VCAP::CloudController::Lifecycles::BUILDPACK
          end
        end
      end
    end
  end
end
