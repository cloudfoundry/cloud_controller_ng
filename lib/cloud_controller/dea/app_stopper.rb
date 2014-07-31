module VCAP::CloudController
  module Dea
    class AppStopper
      attr_reader :message_bus

      def initialize(message_bus)
        @message_bus = message_bus
      end

      def publish_stop(message)
        logger.debug "sending 'dea.stop' with '#{message}'"
        message_bus.publish("dea.stop", message)
      end

      private

      def logger
        @logger ||= Steno.logger("cc.appstopper")
      end
    end
  end
end
