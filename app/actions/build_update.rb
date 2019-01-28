module VCAP::CloudController
  class BuildUpdate
    class InvalidBuild < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.build_update')
    end

    def update(build, message)
      build.db.transaction do
        MetadataUpdate.update(build, message)
      end
      @logger.info("Finished updating metadata on build #{build.guid}")
      build
    rescue Sequel::ValidationFailed => e
      raise InvalidBuild.new(e.message)
    end
  end
end
