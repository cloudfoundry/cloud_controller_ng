# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  module HealthManagerClient
    class << self
      attr_reader :message_bus

      def configure(message_bus = MessageBus)
        @message_bus = message_bus
      end

      def find_crashes(app)
        message = { :droplet => app.guid, :state => :CRASHED }
        crashed_instances = hm_request("status", message, :timeout => 2).first
        if crashed_instances
          crashed_instances[:instances]
        else
          []
        end
      end

      def find_status(app, message_options = {})
        message = { :droplet => app.guid }
        message.merge!(message_options)

        request_options = {
          :expected => app.instances,
          :timeout => 2,
        }

        hm_request("status", message, request_options).first
      end

      def healthy_instances(app)
        message = {
          :droplets => [
            :droplet => app.guid,
            :version => app.version
          ]
        }

        request_options = {
          :expected => 1,
          :timeout => 1
        }

        resp = hm_request("health", message, request_options)
        return 0 unless (resp && resp.size >= 1)
        resp.first[:healthy]
      end

      private

      def hm_request(cmd, args = {}, opts = {})
        subject = "healthmanager.#{cmd}"
        msg = "sending subject: '#{subject}' with args: '#{args}'"
        msg << " and opts: '#{opts}'"
        logger.debug msg
        json = Yajl::Encoder.encode(args)

        response = message_bus.request(subject, json, opts)
        parsed_response = []
        response.each do |json_str|
          parsed_response << Yajl::Parser.parse(json_str,
                                                :symbolize_keys => true)
        end

        parsed_response
      end

      def logger
        @logger ||= Steno.logger("cc.healthmanager.client")
      end
    end
  end
end
