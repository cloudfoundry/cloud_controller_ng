module VCAP::CloudController
  module Dea

    class AppStopper
      attr_reader :message_bus

      def initialize(message_bus)
        @message_bus = message_bus
      end

      def stop(app)
        publish_stop(:droplet => app.guid)
      end

      def publish_stop(args)
        logger.debug "sending 'dea.stop' with '#{args}'"
        message_bus.publish("dea.stop", args)
      end

      def logger
        @logger ||= Steno.logger("cc.appstopper")
      end
    end
  end
end
