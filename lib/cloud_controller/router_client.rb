module VCAP::CloudController
  class RouterClient
    class << self
      def setup(config, message_bus)
        @config = config
        @message_bus = message_bus

        @message_bus.subscribe("router.start") do
          register
        end

        register

        @message_bus.recover do
          register
        end
      end

      def unregister(&callback)
        called = false
        wrapped_callback = proc {
          callback.call unless called || callback.nil?
          called = true
        }

        @message_bus.publish("router.unregister", unregister_message, &wrapped_callback)
        EM.add_timer(message_bus_timeout, &wrapped_callback)
      end

      def message_bus_timeout
        2.0
      end

      private

      def register
        @message_bus.publish("router.register", register_message)
      end

      def register_message
        {
            :host => @config[:bind_address],
            :port => @config[:port],
            :uris => @config[:external_domain],
            :tags => { :component => "CloudController" },
        }
      end

      alias unregister_message register_message
    end
  end
end