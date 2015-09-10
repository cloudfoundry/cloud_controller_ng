module VCAP::CloudController
  module Diego
    module V3
      class Stager
        def initialize(package, messenger, completion_handler, config)
          @package            = package
          @messenger          = messenger
          @completion_handler = completion_handler
          @config             = config
        end

        def stage(staging_details)
          send_stage_package_request(staging_details)

        rescue Errors::ApiError => e
          logger.error('stage.package', staging_guid: staging_details.droplet.guid, error: e)
          staging_complete(staging_details.droplet, { error: { id: 'StagingError', message: e.message } })
          raise e
        end

        def staging_complete(droplet, staging_response)
          @completion_handler.staging_complete(droplet, staging_response)
        end

        private

        def logger
          @logger ||= Steno.logger('cc.stager.client.v3')
        end

        def send_stage_package_request(staging_details)
          @messenger.send_stage_request(@package, @config, staging_details)
        rescue Errors::ApiError => e
          raise e
        rescue => e
          raise Errors::ApiError.new_from_details('StagerError', e)
        end
      end
    end
  end
end
