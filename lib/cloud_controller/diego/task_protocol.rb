require 'cloud_controller/diego/buildpack/buildpack_entry_generator'
require 'cloud_controller/diego/normal_env_hash_to_diego_env_array_philosopher'
require 'cloud_controller/diego/staging_request'
require 'cloud_controller/diego/task_completion_callback_generator'
require 'cloud_controller/diego/buildpack/lifecycle_data'
require 'cloud_controller/diego/protocol/app_volume_mounts'
require 'cloud_controller/diego/task_environment'

module VCAP::CloudController
  module Diego
    class TaskProtocol
      def initialize(egress_rules)
        @egress_rules = egress_rules
      end

      def task_request(task, config)
        app     = task.app
        droplet = task.droplet

        blobstore_url_generator  = CloudController::DependencyLocator.instance.blobstore_url_generator
        task_completion_callback = VCAP::CloudController::Diego::TaskCompletionCallbackGenerator.new(config).generate(task)

        result = {
          'task_guid'           => task.guid,
          'log_guid'            => app.guid,
          'memory_mb'           => task.memory_in_mb,
          'disk_mb'             => task.disk_in_mb,
          'environment'         => envs_for_diego(app, task) || nil,
          'egress_rules'        => @egress_rules.running(app),
          'completion_callback' => task_completion_callback,
          'lifecycle'           => app.lifecycle_type,
          'command'             => task.command,
          'log_source'          => 'APP/TASK/' + task.name,
          'volume_mounts'       => VCAP::CloudController::Diego::Protocol::AppVolumeMounts.new(app)
        }

        if app.lifecycle_type == Lifecycles::BUILDPACK
          result = result.merge({
            'rootfs'       => app.lifecycle_data.stack,
            'droplet_uri'  => blobstore_url_generator.droplet_download_url(droplet),
            'droplet_hash' => droplet.droplet_hash,
          })
        elsif app.lifecycle_type == Lifecycles::DOCKER
          result = result.merge(
            'docker_path' => droplet.docker_receipt_image,
          )

          if droplet.docker_receipt_username.present?
            result = result.merge(
              'docker_user' => droplet.docker_receipt_username,
              'docker_password' => droplet.docker_receipt_password,
            )
          end
        end

        if task.space.isolation_segment_model
          if !task.space.isolation_segment_model.is_shared_segment?
            result['isolation_segment'] = task.space.isolation_segment_model.name
          end
        elsif task.space.organization.default_isolation_segment_model &&
          !task.space.organization.default_isolation_segment_model.is_shared_segment?
          result['isolation_segment'] = task.space.organization.default_isolation_segment_model.name
        end

        result.to_json
      end

      private

      def envs_for_diego(app, task)
        running_envs = VCAP::CloudController::EnvironmentVariableGroup.running.environment_json
        envs         = VCAP::CloudController::Diego::TaskEnvironment.new(app, task, app.space, running_envs).build
        diego_envs   = VCAP::CloudController::Diego::NormalEnvHashToDiegoEnvArrayPhilosopher.muse(envs)

        logger.debug2("task environment: #{diego_envs.map { |e| e['name'] }}")

        diego_envs
      end

      def logger
        @logger ||= Steno.logger('cc.diego.task_protocol')
      end
    end
  end
end
