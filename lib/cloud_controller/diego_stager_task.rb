require 'presenters/message_bus/service_binding_presenter'

module VCAP::CloudController
  class DiegoStagerTask
    attr_reader :message_bus

    def initialize(staging_timeout, message_bus, app, blobstore_url_generator)
      @staging_timeout = staging_timeout
      @message_bus = message_bus
      @app = app
      @blobstore_url_generator = blobstore_url_generator
    end

    def task_id
      @task_id ||= VCAP.secure_uuid
    end

    def stage(&completion_callback)
      @app.update(staging_task_id: task_id)

      logger.info("staging.begin", :app_guid => @app.guid)

      @message_bus.publish("diego.staging.start", staging_request)
    end

    def staging_request
      {
       :app_id => app.guid,
       :task_id => task_id,
       :memory_mb => app.memory,
       :disk_mb => app.disk_quota,
       :file_descriptors => app.file_descriptors,
       :environment => environment,
       :stack => app.stack.name,
       :build_artifacts_cache_download_uri => @blobstore_url_generator.buildpack_cache_download_url(@app),
       :app_bits_download_uri => @blobstore_url_generator.app_package_download_url(app),
       :buildpacks => buildpacks
      }
    end

    private

    def environment
      env = []
      env << {key:"VCAP_APPLICATION", value:app.vcap_application.to_json}
      env << {key:"VCAP_SERVICES", value: app.system_env_json["VCAP_SERVICES"].to_json}
      db_uri = app.database_uri
      env << {key:"DATABASE_URL", value:db_uri} if db_uri
      env << {key:"MEMORY_LIMIT", value:"#{app.memory}m"}
      app.environment_json.each { |k, v| env << {key:k, value:v} }
      env
    end

    def app
      @app
    end

    def buildpacks
      buildpack = app.buildpack

      if buildpack.instance_of?(GitBasedBuildpack)
        buildpackIsHttp = buildpack.to_s =~ /^http/
        buildPackIsNotGit =  !(buildpack.to_s =~ /\.git$/)
        if buildpackIsHttp && buildPackIsNotGit
          return [{key: "custom", url: buildpack.to_s}]
        end
      elsif buildpack.instance_of?(Buildpack)
        return [admin_buildpack_entry(buildpack)]
      end

      Buildpack.list_admin_buildpacks.
         select(&:enabled).
         collect { |buildpack| admin_buildpack_entry(buildpack) }
    end

    def admin_buildpack_entry(buildpack)
      {
          key: buildpack.key,
          url: @blobstore_url_generator.admin_buildpack_download_url(buildpack)
      }
    end

    def service_binding_to_staging_request(service_binding)
      ServiceBindingPresenter.new(service_binding).to_hash
    end

    def logger
      @logger ||= Steno.logger("cc.app_stager")
    end
  end
end
