require "cloud_controller/diego/traditional/buildpack_entry_generator"
require "cloud_controller/diego/traditional/desire_request"
require "cloud_controller/diego/traditional/staging_request"

module VCAP::CloudController
  module Diego
    module Traditional
      class Messenger
        def initialize(enabled, message_bus, blobstore_url_generator)
          @enabled = enabled
          @message_bus = message_bus
          @blobstore_url_generator = blobstore_url_generator
          @buildpack_entry_generator = BuildpackEntryGenerator.new(@blobstore_url_generator)
        end

        def send_desire_request(app)
          @enabled or raise VCAP::Errors::ApiError.new_from_details("DiegoDisabled")

          logger.info("desire.app.begin", :app_guid => app.guid)
          @message_bus.publish("diego.desire.app", desire_request(app).to_json)
        end

        def send_stage_request(app)
          @enabled or raise VCAP::Errors::ApiError.new_from_details("DiegoDisabled")

          app.update(staging_task_id: VCAP.secure_uuid)

          logger.info("staging.begin", :app_guid => app.guid)

          staging_request = StagingRequest.new(app, @blobstore_url_generator, @buildpack_entry_generator)
          @message_bus.publish("diego.staging.start", staging_request.as_json)
        end

        def desire_request(app)
          DesireRequest.new(app, @blobstore_url_generator)
        end

        private

        def logger
          @logger ||= Steno.logger("cc.diego.messenger")
        end
      end
    end
  end
end
