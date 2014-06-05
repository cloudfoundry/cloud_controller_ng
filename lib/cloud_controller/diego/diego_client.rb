module VCAP::CloudController
  class DiegoClient
    def initialize(enabled, message_bus, tps_reporter, blobstore_url_generator)
      @enabled = enabled
      @message_bus = message_bus
      @tps_reporter = tps_reporter
      @blobstore_url_generator = blobstore_url_generator
      @buildpack_entry_generator = DiegoBuildpackEntryGenerator.new(@blobstore_url_generator)
    end

    def running_enabled(app)
      @enabled && (app.environment_json || {})["CF_DIEGO_RUN_BETA"] == "true"
    end

    def staging_enabled(app)
      return false unless @enabled
      running_enabled(app) || ((app.environment_json || {})["CF_DIEGO_BETA"] == "true")
    end

    def staging_needed(app)
      staging_enabled(app) && (app.needs_staging? || app.detected_start_command.empty?)
    end

    def send_desire_request(app)
      logger.info("desire.app.begin", :app_guid => app.guid)
      @message_bus.publish("diego.desire.app", desire_request(app))
    end

    def send_stage_request(app, staging_task_id)
      app.update(staging_task_id: staging_task_id)

      logger.info("staging.begin", :app_guid => app.guid)

      @message_bus.publish("diego.staging.start", staging_request(app))
    end

    def desire_request(app)
      {
          process_guid: lrp_guid(app),
          memory_mb: app.memory,
          disk_mb: app.disk_quota,
          file_descriptors: app.file_descriptors,
          droplet_uri: @blobstore_url_generator.droplet_download_url(app),
          stack: app.stack.name,
          start_command: app.detected_start_command,
          environment: environment(app),
          num_instances: desired_instances(app),
          routes: app.uris,
          health_check_timeout_in_seconds: app.health_check_timeout,
          log_guid: app.guid,
      }
    end

    def desired_instances(app)
      app.started? ? app.instances : 0
    end

    def staging_request(app)
      {
          :app_id => app.guid,
          :task_id => app.staging_task_id,
          :memory_mb => app.memory,
          :disk_mb => app.disk_quota,
          :file_descriptors => app.file_descriptors,
          :environment => environment(app),
          :stack => app.stack.name,
          :build_artifacts_cache_download_uri => @blobstore_url_generator.buildpack_cache_download_url(app),
          :app_bits_download_uri => @blobstore_url_generator.app_package_download_url(app),
          :buildpacks => @buildpack_entry_generator.buildpack_entries(app)
      }
    end

    def lrp_instances(app)
      uri = URI("#{@tps_reporter}/lrps/#{lrp_guid(app)}")

      http = Net::HTTP.new(uri.host)
      http.read_timeout = 10
      http.open_timeout = 10

      body = http.get(uri.path).body

      result = []

      tps_instances = JSON.parse(body)
      tps_instances.each do |instance|
        result << {
          process_guid: instance['process_guid'],
          instance_guid: instance['instance_guid'],
          index: instance['index'],
          state: instance['state'].upcase,
          since: instance['since_in_ns'].to_i / 1_000_000_000,
        }
      end

      result
    end

    def environment(app)
      env = []
      env << {key: "VCAP_APPLICATION", value: app.vcap_application.to_json}
      env << {key: "VCAP_SERVICES", value: app.system_env_json["VCAP_SERVICES"].to_json}
      db_uri = app.database_uri
      env << {key: "DATABASE_URL", value: db_uri} if db_uri
      env << {key: "MEMORY_LIMIT", value: "#{app.memory}m"}
      app_env_json = app.environment_json || {}
      app_env_json.each { |k, v| env << {key: k, value: v} }
      env
    end

    def logger
      @logger ||= Steno.logger("cc.diego_client")
    end

    def lrp_guid(app)
      "#{app.guid}-#{app.version}"
    end
  end
end

module VCAP::CloudController
  class DiegoBuildpackEntryGenerator
    def initialize(blobstore_url_generator)
      @blobstore_url_generator = blobstore_url_generator
    end

    def buildpack_entries(app)
      buildpack = app.buildpack

      if buildpack.instance_of?(GitBasedBuildpack)
        if is_zip_format(buildpack)
          return [custom_buildpack_entry(buildpack)]
        else
          return default_admin_buildpacks
        end
      end

      if buildpack.instance_of?(Buildpack)
        return [admin_buildpack_entry(buildpack)]
      end

      default_admin_buildpacks
    end

    def is_zip_format(buildpack)
      buildpackIsHttp = buildpack.url =~ /^http/
      buildPackIsZip= buildpack.url=~ /\.zip$/
      buildpackIsHttp && buildPackIsZip
    end

    def custom_buildpack_entry(buildpack)
      {name: "custom", key: buildpack.url, url: buildpack.url}
    end

    def default_admin_buildpacks
      Buildpack.list_admin_buildpacks.
          select(&:enabled).
          collect { |buildpack| admin_buildpack_entry(buildpack) }
    end

    def admin_buildpack_entry(buildpack)
      {
          name: buildpack.name,
          key: buildpack.key,
          url: @blobstore_url_generator.admin_buildpack_download_url(buildpack)
      }
    end
  end
end