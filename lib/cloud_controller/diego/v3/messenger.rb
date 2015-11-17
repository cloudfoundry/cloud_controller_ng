module VCAP::CloudController
  module Diego
    module V3
      class Messenger
        def initialize(stager_client, protocol)
          @stager_client = stager_client
          @protocol      = protocol
        end

        def send_stage_request(package, config, staging_details)
          logger.info('staging.begin', package_guid: package.guid)

          staging_guid    = staging_details.droplet.guid
          staging_message = @protocol.stage_package_request(package, config, staging_details)
          @stager_client.stage(staging_guid, staging_message)
        end

        private

        def logger
          @logger ||= Steno.logger('cc.diego.messenger.v3')
        end
      end
    end
  end
end
