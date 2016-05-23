module VCAP
  class VarsBuilder
    def initialize(app,
                   memory_limit: nil,
                   staging_disk_in_mb: nil,
                   space: nil,
                   file_descriptors: nil,
                   version: nil
                  )
      @app = app
      @staging_disk_in_mb = staging_disk_in_mb
      @memory_limit = memory_limit
      @space = space
      @file_descriptors = file_descriptors
      @version = version
    end

    def to_hash
      if @app.class == VCAP::CloudController::AppModel
        app_name = @app.name
        uris = @app.routes.map(&:fqdn)
      else
        app_name = @app.app_guid.nil? ? @app.name : @app.app.name
        @staging_disk_in_mb = @app.disk_quota if @staging_disk_in_mb.nil?
        @memory_limit = @app.memory if @memory_limit.nil?
        @file_descriptors = @app.file_descriptors if @file_descriptors.nil?
        @version = @app.version
        uris = @app.uris
      end

      @space = @app.space if @space.nil?

      env_hash = {
        limits: {
        },
        application_name: app_name,
        application_uris: uris,
        name: @app.name,
        space_name: @space.name,
        space_id: @space.guid,
        uris: uris,
        users: nil
      }

      unless @file_descriptors.nil?
        env_hash.deep_merge!({
          limits: {
            fds: @file_descriptors
          }
        })
      end

      unless @memory_limit.nil?
        env_hash.deep_merge!({
          limits: {
            mem: @memory_limit
          }
        })
      end

      unless @staging_disk_in_mb.nil?
        env_hash.deep_merge!({
          limits: {
            disk: @staging_disk_in_mb
          }
        })
      end

      unless @version.nil?
        env_hash.deep_merge!({
          version: @version,
          application_version: @version
        })
      end

      unless @app.guid.nil?
        env_hash.deep_merge!({
          application_id: @app.guid,
        })
      end

      env_hash
    end
  end
end
