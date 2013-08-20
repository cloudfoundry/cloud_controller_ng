# Copyright (c) 2009-2012 VMware, Inc.

require "steno"

require File.expand_path("../dea/dea_client", __FILE__)

module VCAP::CloudController
  class << self
    attr_accessor :health_manager_respondent
  end

  class HealthManagerRespondent
    attr_reader :logger, :config
    attr_reader :message_bus, :dea_client

    # Semantically there should only be one such thing, although
    # I'm hesitant about making singletons
    # - Jesse
    def initialize(dea_client, message_bus)
      @logger = Steno.logger("cc.hm")
      @dea_client = dea_client
      @message_bus = message_bus
    end

    def handle_requests
      message_bus.subscribe("health.stop", :queue => "cc") do |decoded_msg|
        process_stop(decoded_msg)
      end

      message_bus.subscribe("health.start", :queue => "cc") do |decoded_msg|
        process_start(decoded_msg)
      end
    end

    def process_start(payload)
      begin
        app_id = payload.fetch(:droplet)
        indices = payload.fetch(:indices)
        version = payload.fetch(:version)
        running = payload.fetch(:running)
      rescue KeyError => e
        logger.error "cloudcontroller.hm.malformed-request",
          :error => e.message,
          :payload => payload
        return
      end

      app = Models::App[:guid => app_id]
      return unless app
      return unless app.started?
      return unless version == app.version
      return unless app.droplet_hash

      current_running = running[app.version.to_sym] || 0
      return unless current_running < app.instances

      dea_client.start_instances_with_message(app, indices)
    end

    def process_stop(payload)
      begin
        app_id = payload.fetch(:droplet)
        instances = payload.fetch(:instances)
        running = payload.fetch(:running)
      rescue KeyError => e
        logger.error "cloudcontroller.hm.malformed-request",
          :error => e.message,
          :payload => payload
        return
      end

      app = Models::App[:guid => app_id]

      if !app
        stop_runaway_app(app_id)
      elsif stop_instances?(app, instances, running)
        dea_client.stop_instances(app, instances.keys)
      end
    end

    def stop_app(app)
      dea_client.stop(app)
    end

    def stop_runaway_app(app_id)
      dea_client.stop(Models::App.new(:guid => app_id))
    end

    def stop_instances?(app, instances, running)
      instances.group_by { |_, v| v }.each do |version, versions|
        instances_remaining =
          if running.key?(version.to_sym)
            running[version.to_sym] - versions.size
          else
            0
          end

        if version != app.version
          unless (running[app.version.to_sym] || 0) > 0
            return false
          end
        elsif instances_remaining < app.instances && app.started?
          logger.error "cloudcontroller.hm.invalid-request",
                       :instances => instances, :app => app.guid,
                       :desired_instances => app.instances,
                       :remaining_instances => instances_remaining

          return false
        end
      end

      true
    end
  end
end