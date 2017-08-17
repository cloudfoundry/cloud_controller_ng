module CloudController
  module Presenters
    module V2
      class ProcessModelPresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::ProcessModel'

        REDACTED_MESSAGE = '***'.freeze

        def entity_hash(controller, process, opts, depth, parents, orphans=nil)
          entity = {
            'name'                       => process.name,
            'production'                 => process.production,
            'space_guid'                 => process.space.guid,
            'stack_guid'                 => process.stack.guid,
            'buildpack'                  => buildpack_name_or_url(process.buildpack),
            'detected_buildpack'         => process.detected_buildpack,
            'detected_buildpack_guid'    => process.detected_buildpack_guid,
            'environment_json'           => redact(process.environment_json, can_read_env?(process)),
            'memory'                     => process.memory,
            'instances'                  => process.instances,
            'disk_quota'                 => process.disk_quota,
            'state'                      => process.state,
            'version'                    => process.version,
            'command'                    => process.command,
            'console'                    => process.console,
            'debug'                      => process.debug,
            'staging_task_id'            => process.staging_task_id,
            'package_state'              => process.package_state,
            'health_check_type'          => process.health_check_type,
            'health_check_timeout'       => process.health_check_timeout,
            'health_check_http_endpoint' => process.health_check_http_endpoint,
            'staging_failed_reason'      => process.staging_failed_reason,
            'staging_failed_description' => process.staging_failed_description,
            'diego'                      => process.diego,
            'docker_image'               => process.docker_image,
            'docker_credentials'         => {
              'username' => process.docker_username,
              'password' => process.docker_username && REDACTED_MESSAGE,
            },
            'package_updated_at'         => process.package_updated_at,
            'detected_start_command'     => process.detected_start_command,
            'enable_ssh'                 => process.app.enable_ssh,
            'ports'                      => VCAP::CloudController::Diego::Protocol::OpenProcessPorts.new(process).to_a,
          }

          entity.merge!(RelationsPresenter.new.to_hash(controller, process, opts, depth, parents, orphans))
        rescue NoMethodError => e
          logger.info("Error presenting app: no associated object: #{e}")
          nil
        end

        private

        def logger
          @logger ||= Steno.logger('cc.presenter.app')
        end

        def buildpack_name_or_url(buildpack)
          if buildpack.class == VCAP::CloudController::CustomBuildpack
            CloudController::UrlSecretObfuscator.obfuscate(buildpack.url)
          elsif buildpack.class == VCAP::CloudController::Buildpack
            buildpack.name
          end
        end

        def can_read_env?(app)
          VCAP::CloudController::Security::AccessContext.new.can?(:read_env, app)
        end

        def redact(attr, has_permission=false)
          if has_permission
            attr
          else
            { 'redacted_message' => '[PRIVATE DATA HIDDEN]' }
          end
        end
      end
    end
  end
end
