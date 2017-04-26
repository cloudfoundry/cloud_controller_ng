module VCAP::CloudController
  class BuildDelete
    def initialize(stagers)
      @stagers = stagers
    end

    def delete(builds)
      builds = Array(builds)

      builds.each do |build|
        fire_and_forget_staging_cancel(build)
        build.destroy
      end
    end

    private

    def fire_and_forget_staging_cancel(build)
      return if build.in_final_state?
      @stagers.stager_for_app(build.app).stop_stage(build.guid)
    rescue => e
      logger.error("failed to request staging cancellation for build: #{build.guid}, error: #{e.message}")
    end

    def logger
      @logger ||= Steno.logger('cc.build_delete')
    end
  end
end
