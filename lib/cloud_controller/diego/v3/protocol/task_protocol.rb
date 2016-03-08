require 'cloud_controller/diego/buildpack/v3/buildpack_entry_generator'
require 'cloud_controller/diego/normal_env_hash_to_diego_env_array_philosopher'
require 'cloud_controller/diego/staging_request'
require 'cloud_controller/diego/task_completion_callback_generator'
require 'cloud_controller/diego/buildpack/lifecycle_data'

module VCAP::CloudController
  module Diego
    module V3
      module Protocol
        class TaskProtocol
          def initialize(egress_rules)
            @egress_rules = egress_rules
          end

          def task_request(task, config)
            app = task.app
            droplet = task.droplet

            blobstore_url_generator = CloudController::DependencyLocator.instance.blobstore_url_generator
            task_completion_callback = VCAP::CloudController::Diego::TaskCompletionCallbackGenerator.new(config).generate(task)

            result = {
              'task_guid' => task.guid,
              'log_guid' => app.guid,
              'memory_mb' => task.memory_in_mb,
              'disk_mb' => config[:default_app_disk_in_mb],
              'environment' => envs_for_diego(app, task) || nil,
              'egress_rules' => @egress_rules.running(app),
              'completion_callback' => task_completion_callback,
              'lifecycle' => app.lifecycle_type,
              'command' => task.command,
              'log_source' => 'APP/TASK/' + task.name
            }

            if app.lifecycle_type == Lifecycles::BUILDPACK
              result = result.merge({
                'rootfs' => app.lifecycle_data.stack,
                'droplet_uri' => blobstore_url_generator.v3_droplet_download_url(droplet),
              })
            elsif app.lifecycle_type == Lifecycles::DOCKER
              result = result.merge(
                'docker_path' => droplet.docker_receipt_image,
              )
            end

            result.to_json
          end

          private

          def envs_for_diego(app, task)
            running_envs = VCAP::CloudController::EnvironmentVariableGroup.running.environment_json
            envs = VCAP::CloudController::Diego::V3::Environment.new(app, task, app.space, running_envs).build(task.environment_variables)
            diego_envs = VCAP::CloudController::Diego::NormalEnvHashToDiegoEnvArrayPhilosopher.muse(envs)

            logger.debug2("task environment: #{diego_envs.map { |e| e['name'] }}")

            diego_envs
          end

          def task_completion_callback(task)
          end

          def logger
            @logger ||= Steno.logger('cc.diego.task_protocol')
          end
        end
      end
    end
  end
end
