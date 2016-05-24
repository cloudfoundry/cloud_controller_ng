module VCAP
  class VarsBuilder
    def initialize(process,
                   memory_limit: nil,
                   staging_disk_in_mb: nil,
                   space: nil,
                   file_descriptors: nil,
                   version: nil
                  )
      @process = process
      @staging_disk_in_mb = staging_disk_in_mb
      @memory_limit = memory_limit
      @space = space
      @file_descriptors = file_descriptors
      @version = version
    end

    def to_hash
      if @process.class == VCAP::CloudController::AppModel
        app_name = @process.name
        uris = @process.routes.map(&:fqdn)
      else
        app_name = @process.is_v3? ? @process.app.name : @process.name
        @staging_disk_in_mb ||= @process.disk_quota
        @memory_limit ||= @process.memory
        @file_descriptors ||= @process.file_descriptors
        @version = @process.version
        uris = @process.uris
      end

      @space = @process.space if @space.nil?

      env_hash = {
        limits: {},
        application_name: app_name,
        application_uris: uris,
        name: @process.name,
        space_name: @space.name,
        space_id: @space.guid,
        uris: uris,
        users: nil
      }

      env_hash[:limits][:fds] = @file_descriptors if @file_descriptors
      env_hash[:limits][:mem] = @memory_limit if @memory_limit
      env_hash[:limits][:disk] = @staging_disk_in_mb if @staging_disk_in_mb
      env_hash[:application_id] = @process.guid if @process.guid

      unless @version.nil?
        env_hash[:version] = @version
        env_hash[:application_version] = @version
      end

      env_hash
    end
  end
end
