module VCAP
  class VarsBuilder
    def initialize(app,
                   memory_limit: nil,
                   disk_limit: nil,
                   space: nil,
                   file_descriptors: nil,
                   version: nil
                  )
      @app = app
      @disk_limit = disk_limit
      @memory_limit = memory_limit
      @space = space
      @file_descriptors = file_descriptors
      @version = version
    end

    def vcap_application
      if @app.class == VCAP::CloudController::AppModel
        app_name = @app.name
        uris = @app.routes.map(&:fqdn)
      else
        app_name = @app.app_guid.nil? ? @app.name : @app.app.name
        @disk_limit = @app.disk_quota if @disk_limit.nil?
        @memory_limit = @app.memory if @memory_limit.nil?
        @file_descriptors = @app.file_descriptors if @file_descriptors.nil?
        @version = @app.version
        uris = @app.uris
      end

      @space = @app.space if @space.nil?

      env_hash = {
        'limits' => {
        },
        'application_name' => app_name,
        'application_uris' => uris,
        'name' => @app.name,
        'space_name' => @space.name,
        'space_id' => @space.guid,
        'uris' => uris,
        'users' => nil
      }

      if !@file_descriptors.nil?
        env_hash.deep_merge!({
          'limits' => {
            'fds' => @file_descriptors
          }
        })
      end

      if !@memory_limit.nil?
        env_hash.deep_merge!({
          'limits' => {
            'mem' => @memory_limit
          }
        })
      end

      if !@disk_limit.nil?
        env_hash.deep_merge!({
          'limits' => {
            'disk' => @disk_limit
          }
        })
      end

      if !@version.nil?
        env_hash.deep_merge!({
          'version' => @version,
          'application_version' => @version
        })
      end

      if !@app.guid.nil?
        env_hash.deep_merge!({
          'application_id' => @app.guid,
        })
      end

      env_hash
    end
  end
end
