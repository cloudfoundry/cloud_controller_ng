module VCAP::CloudController
  class StagingCancel
    def initialize(stagers)
      @stagers = stagers
    end

    def cancel(builds)
      builds = Array(builds)

      builds.each do |build|
        next if build.in_final_state?

        begin
          @stagers.stager_for_build(build).stop_stage(build.guid)
        rescue StandardError => e
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
