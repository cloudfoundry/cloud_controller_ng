module VCAP::CloudController
  module Diego
    class Stager
      def initialize(config)
        @config = config
      end

      def stage(staging_details)
        send_stage_package_request(staging_details)

      rescue CloudController::Errors::ApiError => e
        logger.error('stage.package', package_guid: staging_details.package.guid, staging_guid: staging_details.droplet.guid, error: e)
        staging_complete(staging_details.droplet, { error: { id: 'StagingError', message: e.message } })
        raise e
      end

      def staging_complete(droplet, staging_response, with_start=false)
        completion_handler(droplet).staging_complete(staging_response, with_start)
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

      def completion_handler(droplet)
        if droplet.lifecycle_type == Lifecycles::BUILDPACK
          Diego::Buildpack::StagingCompletionHandler.new(droplet)
        elsif droplet.lifecycle_type == Lifecycles::DOCKER
          Diego::Docker::StagingCompletionHandler.new(droplet)
        else
          raise "Unprocessable lifecycle type for stager: #{droplet.lifecycle_type}"
        end
      end
    end
  end
end
