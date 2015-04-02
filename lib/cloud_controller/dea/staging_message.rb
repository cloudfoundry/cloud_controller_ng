module VCAP::CloudController
  module Dea
    class StagingMessage
      def initialize(config, blobstore_url_generator)
        @blobstore_url_generator = blobstore_url_generator
        @config = config
      end

      def staging_request(app, task_id)
        {
          app_id:                       app.guid,
          stack:                        app.stack.name,
          task_id:                      task_id,
          properties:                   staging_task_properties(app),
          # All url generation should go to blobstore_url_generator
          download_uri:                 @blobstore_url_generator.app_package_download_url(app),
          upload_uri:                   @blobstore_url_generator.droplet_upload_url(app),
          buildpack_cache_download_uri: @blobstore_url_generator.buildpack_cache_download_url(app),
          buildpack_cache_upload_uri:   @blobstore_url_generator.buildpack_cache_upload_url(app),
          start_message:                start_app_message(app),
          admin_buildpacks:             admin_buildpacks,
          egress_network_rules:         staging_egress_rules,
        }
      end

      private

      def staging_task_properties(app)
        staging_task_base_properties(app).merge(app.buildpack.staging_message)
      end

      def staging_task_base_properties(app)
        staging_env = EnvironmentVariableGroup.staging.environment_json
        app_env     = app.environment_json || {}
        stack_env   = { 'CF_STACK' => app.stack.name }
        env         = staging_env.merge(app_env).merge(stack_env).map { |k, v| "#{k}=#{v}" }

        {
          services: app.service_bindings.map { |sb| service_binding_to_staging_request(sb) },
          resources: {
            memory: app.memory,
            disk: app.disk_quota,
            fds: app.file_descriptors
          },

          environment: env,
          meta: app.metadata
        }
      end

      def service_binding_to_staging_request(service_binding)
        ServiceBindingPresenter.new(service_binding).to_hash
      end

      def staging_egress_rules
        staging_security_groups = SecurityGroup.where(staging_default: true).all
        EgressNetworkRulesPresenter.new(staging_security_groups).to_array
      end

      def admin_buildpacks
        AdminBuildpacksPresenter.new(@blobstore_url_generator).to_staging_message_array
      end

      def start_app_message(app)
        msg = Dea::StartAppMessage.new(app, 0, @config, @blobstore_url_generator)
        msg[:sha1] = nil
        msg
      end
    end

    class PackageDEAStagingMessage < StagingMessage
      attr_reader :stack, :memory_limit, :disk_limit, :buildpack_key, :buildpack_git_url, :log_id, :droplet_guid

      def initialize(package, droplet_guid, log_id, stack, memory_limit,
                     disk_limit, buildpack_key, buildpack_git_url, config,
                     environment_variables, blobstore_url_generator)
        @app_guid              = package.app_guid
        @package               = package
        @stack                 = stack
        @memory_limit          = memory_limit
        @disk_limit            = disk_limit
        @buildpack_key         = buildpack_key
        @buildpack_git_url     = buildpack_git_url
        @environment_variables = environment_variables
        @droplet_guid          = droplet_guid
        @log_id                = log_id
        super(config, blobstore_url_generator)
      end

      def staging_request
        {
          app_id:                       log_id,
          stack:                        stack,
          task_id:                      droplet_guid,
          # All url generation should go to blobstore_url_generator
          download_uri:                 @blobstore_url_generator.package_download_url(@package),
          upload_uri:                   @blobstore_url_generator.package_droplet_upload_url(droplet_guid),
          buildpack_cache_upload_uri:   @blobstore_url_generator.v3_app_buildpack_cache_upload_url(@app_guid, @stack),
          buildpack_cache_download_uri: @blobstore_url_generator.v3_app_buildpack_cache_download_url(@app_guid, @stack),
          admin_buildpacks:             admin_buildpacks,
          memory_limit:                 memory_limit,
          disk_limit:                   disk_limit,
          egress_network_rules:         staging_egress_rules,
          properties:                   {
            environment:       @environment_variables.map { |k, v| "#{k}=#{v}" },
            buildpack_key:     buildpack_key,
            buildpack_git_url: buildpack_git_url,
          }
        }
      end
    end
  end
end
