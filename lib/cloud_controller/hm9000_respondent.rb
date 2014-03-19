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
        logger.error "cloudcontroller.hm9000.malformed-request",
                     :error => e.message,
                     :payload => message
        return
      end

      should_stop, reason = instance_needs_to_stop?(app_id, version, instance_index, is_duplicate)
      if should_stop
        dea_client.stop_instances(app_id, instance_guid)
        logger.info "cloudcontroller.hm9000.will-stop", :reason => reason, :payload => message
      else
        logger.info "cloudcontroller.hm9000.will-not-stop", :payload => message
      end
    end

    def process_hm9000_start(message)
      begin
        app_id = message.fetch("droplet")
        version = message.fetch("version")
        instance_index = message.fetch("instance_index")
      rescue KeyError => e
        Loggregator.emit_error(app_id, "Bad request from health manager: #{e.message}, payload: #{message}")
        logger.error "cloudcontroller.hm9000.malformed-request",
                     :error => e.message,
                     :payload => message
        return
      end

      app = App[:guid => app_id]
      should_start, reason = instance_needs_to_start?(app, version, instance_index)
      if should_start
        dea_client.start_instance_at_index(app, instance_index)
        logger.info "cloudcontroller.hm9000.will-start", :reason => reason, :payload => message
      else
        logger.info "cloudcontroller.hm9000.will-not-start", :payload => message
      end
    end

    def instance_needs_to_stop?(app_id, version, instance_index, is_duplicate)
      app = App[:guid => app_id]

      if !app
        return true, "App not found"
      end

      if app.staging_failed?
        return true, "App failed to stage"
      end

      if is_duplicate
        return true, "Instance is duplicate"
      end

      if app.version != version
        return true, "Version is not current (#{app.version})"
      end

      if instance_index >= app.instances
        return true, "Instance index is outside desired number of instances (#{app.instances})"
      end

      if app.stopped?
        return true, "App is in STOPPED state"
      end

      false
    end

    def instance_needs_to_start?(app, version, instance_index)
      if !app
        return false, "App not found"
      end

      if app.version != version
        return false, "Version is not current (#{app.version})"
      end

      if instance_index >= app.instances
        return false, "Instance index is outside desired number of instances (#{app.instances})"
      end

      if !app.droplet_hash
        return false, "App is not uploaded (no droplet hash)"
      end

      if !app.staged?
        return false, "App is not staged"
      end

      if !app.started?
        return false, "App is not in STARTED state"
      end

      true
    end
  end
end
