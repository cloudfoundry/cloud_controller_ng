module VCAP::CloudController
  module Diego
    class Stager
      def initialize(config)
        @config = config
      end

      def stage(staging_details)
        send_stage_package_request(staging_details)
      rescue CloudController::Errors::ApiError => e
        logger.error('stage.package', package_guid: staging_details.package.guid, staging_guid: staging_details.staging_guid, error: e)
        build = BuildModel.find(guid: staging_details.staging_guid)
        staging_complete(build, { error: { id: 'StagingError', message: e.message } }) if build
        raise e
      end

      def staging_complete(build, staging_response, with_start=false)
        completion_handler(build).staging_complete(staging_response, with_start)
      end

      def stop_stage(staging_guid)
        messenger.send_stop_staging_request(staging_guid)
      end

      private

      def logger
        @logger ||= Steno.logger('cc.stager')
      end

      def send_stage_package_request(staging_details)
        messenger.send_stage_request(@config, staging_details)
      rescue CloudController::Errors::ApiError => e
        raise e
      rescue => e
        raise CloudController::Errors::ApiError.new_from_details('StagerError', e)
      end

      def messenger
        Diego::Messenger.new
      end

      def completion_handler(build)
        if build.lifecycle_type == Lifecycles::BUILDPACK
          Diego::Buildpack::StagingCompletionHandler.new(build)
        elsif build.lifecycle_type == Lifecycles::DOCKER
          Diego::Docker::StagingCompletionHandler.new(build)
        else
          raise "Unprocessable lifecycle type for stager: #{build.lifecycle_type}"
        end
      end
    end
  end
end
