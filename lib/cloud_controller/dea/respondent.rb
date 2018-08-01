require 'repositories/app_event_repository'

module VCAP::CloudController
  module Dea
    class Respondent
      attr_accessor :logger

      attr_reader :config
      attr_reader :message_bus

      CRASH_EVENT_QUEUE = 'crash_event_registration'.freeze

      def initialize(message_bus)
        @logger = Steno.logger('cc.dea_respondent')
        @message_bus = message_bus
      end

      def start
        message_bus.subscribe('droplet.exited', queue: CRASH_EVENT_QUEUE) do |decoded_msg|
          process_droplet_exited_message(decoded_msg)
        end
      end

      def crashed_app?(decoded_message)
        decoded_message['reason'] && decoded_message['reason'].downcase == 'crashed'
      end

      def process_droplet_exited_message(decoded_message)
        app_guid = decoded_message['droplet']

        app = App[guid: app_guid]

        if app && crashed_app?(decoded_message)
          app_event_repository = Repositories::AppEventRepository.new
          app_event_repository.create_app_exit_event(app, decoded_message)
        end
      end
    end
  end
end
