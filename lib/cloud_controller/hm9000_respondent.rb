# Copyright (c) 2009-2012 VMware, Inc.

require "steno"

require File.expand_path("../dea/dea_client", __FILE__)

module VCAP::CloudController
  class HM9000Respondent
    attr_reader :logger, :config
    attr_reader :message_bus, :dea_client

    def initialize(dea_client, message_bus)
      @logger = Steno.logger("cc.hm9000")
      @dea_client = dea_client
      @message_bus = message_bus
    end

    def handle_requests
      message_bus.subscribe("hm9000.stop", :queue => "cc") do |decoded_msg|
        process_hm9000_stop(decoded_msg)
      end

      message_bus.subscribe("hm9000.start", :queue => "cc") do |decoded_msg|
        process_hm9000_start(decoded_msg)
      end
    end

    def process_hm9000_stop(message)
      begin
        app_id = message.fetch("droplet")
        version = message.fetch("version")
        instance_guid = message.fetch("instance_guid")
        instance_index = message.fetch("instance_index")
        is_duplicate = message.fetch("is_duplicate")
      rescue KeyError => e
        Loggregator.emit_error(app_id, "Bad request from health manager: #{e.message}, payload: #{message}")
        logger.error "cloudcontroller.hm.malformed-request",
                     :error => e.message,
                     :payload => message
        return
      end

      if instance_needs_to_stop?(app_id, version, instance_index, is_duplicate)
        dea_client.stop_instance(app_id, instance_guid)
      end
    end

    def process_hm9000_start(message)
      begin
        app_id = message.fetch("droplet")
        version = message.fetch("version")
        instance_index = message.fetch("instance_index")
      rescue KeyError => e
        Loggregator.emit_error(app_id, "Bad request from health manager: #{e.message}, payload: #{message}")
        logger.error "cloudcontroller.hm.malformed-request",
                     :error => e.message,
                     :payload => message
        return
      end

      app = App[:guid => app_id]

      if app && instance_needs_to_start?(app, version, instance_index)
        dea_client.start_instance_at_index(app, instance_index)
      end
    end

    def instance_needs_to_stop?(app_id, version, instance_index, is_duplicate)
      app = App[:guid => app_id]

      !app ||
        is_duplicate ||
        app.version != version ||
        instance_index >= app.instances ||
        app.stopped?
    end

    def instance_needs_to_start?(app, version, instance_index)
      app.version == version &&
        instance_index < app.instances &&
        app.droplet_hash &&
        app.staged? &&
        app.started?
    end
  end
end
