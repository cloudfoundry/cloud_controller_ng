module VCAP::CloudController
  class StagingCancel
    def initialize(stagers)
      @stagers = stagers
    end

    def cancel(builds)
      builds = Array(builds)

      builds.each do |build|
        begin
          next if build.in_final_state?
          @stagers.stager_for_app(build.app).stop_stage(build.guid)

          build.record_staging_stopped
        rescue => e
          logger.error("failed to request staging cancellation for build: #{build.guid}, error: #{e.message}")
        end
      end
    end

    private

    def logger
      @logger ||= Steno.logger('cc.build_delete')
    end
  end
end
