module CloudController
  module Presenters
    module V2
      class ProcessModelPresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::ProcessModel'

        REDACTED_MESSAGE = '***'.freeze

        def entity_hash(controller, app, opts, depth, parents, orphans=nil)
          entity = {
            'name'                       => app.name,
            'production'                 => app.production,
            'space_guid'                 => app.space.guid,
            'stack_guid'                 => app.stack.guid,
            'buildpack'                  => buildpack_name_or_url(app.buildpack),
            'detected_buildpack'         => app.detected_buildpack,
            'detected_buildpack_guid'    => app.detected_buildpack_guid,
            'environment_json'           => redact(app.environment_json, can_read_env?(app)),
            'memory'                     => app.memory,
            'instances'                  => app.instances,
            'disk_quota'                 => app.disk_quota,
            'state'                      => app.state,
            'version'                    => app.version,
            'command'                    => app.command,
            'console'                    => app.console,
            'debug'                      => app.debug,
            'staging_task_id'            => app.staging_task_id,
            'package_state'              => app.package_state,
            'health_check_type'          => app.health_check_type,
            'health_check_timeout'       => app.health_check_timeout,
            'health_check_http_endpoint' => app.health_check_http_endpoint,
            'staging_failed_reason'      => app.staging_failed_reason,
            'staging_failed_description' => app.staging_failed_description,
            'diego'                      => app.diego,
            'docker_image'               => app.docker_image,
            'docker_credentials'         => {
              'username' => app.docker_username,
              'password' => app.docker_username && REDACTED_MESSAGE,
            },
            'package_updated_at'         => app.package_updated_at,
            'detected_start_command'     => app.detected_start_command,
            'enable_ssh'                 => app.enable_ssh,
            'ports'                      => VCAP::CloudController::Diego::Protocol::OpenProcessPorts.new(app).to_a,
          }

          entity.merge!(RelationsPresenter.new.to_hash(controller, app, opts, depth, parents, orphans))
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
