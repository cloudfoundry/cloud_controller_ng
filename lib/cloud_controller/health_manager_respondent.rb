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
    def initialize(config)
      @logger = config.fetch(:logger, Steno.logger("cc.hm"))
      @dea_client = config.fetch(:dea_client, DeaClient)
      @message_bus = dea_client.message_bus

      @config = config

      subject = "cloudcontrollers.hm.requests.#{config[:cc_partition]}"
      message_bus.subscribe(subject, :queue => "cc") do |decoded_msg|
        process_hm_request(decoded_msg)
      end
    end

    # @param [Hash] payload the decoded request message
    def process_hm_request(payload)
      logger.debug("hm request: #{payload.inspect}")
      case payload[:op]
      when "START"
        process_hm_start(payload)
      when "STOP"
        process_hm_stop(payload)
      else
        logger.warn("Unknown operated requested: #{payload[:op]}, payload: #{payload.inspect}")
      end
    end

    private
    def process_hm_start(payload)
      # TODO: Ideally we should validate the message here with Membrane
      begin
        app_id = payload.fetch(:droplet)
        indices = payload.fetch(:indices)
        last_updated = payload.fetch(:last_updated)
        version = payload.fetch(:version)
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
      return if last_updated && (last_updated.to_i != app.updated_at.to_i)

      message_override = {}
      if payload[:flapping]
        message_override[:flapping] = true
      end

      dea_client.start_instances_with_message(app, indices, message_override)
    end

    def process_hm_stop(payload)
      # TODO: Ideally we should validate the message here with Membrane
      begin
        app_id = payload.fetch(:droplet)
        indices = payload.fetch(:instances)
      rescue KeyError => e
        logger.error "cloudcontroller.hm.malformed-request",
          :error => e.message,
          :payload => payload
        return
      end

      app = Models::App[:guid => app_id]

      instances_remaining = (app ? app.instances : 0) - indices.size

      if !app
        stop_runaway_app(app_id)
      #elsif instances_remaining < app.instances && app.started?
      #  logger.error "cloudcontroller.hm.invalid-request", :op => "STOP",
      #    :indices => indices, :app => app.guid,
      #    :desired_instances => app.instances,
      #    :remaining_instances => instances_remaining
      elsif instances_remaining <= 0
        scale_to_zero(app, indices)
      else
        dea_client.stop_instances(app, indices)
      end
    end

    def stop_app(app)
      dea_client.stop(app)
    end

    def stop_runaway_app(app_id)
      dea_client.stop(Models::App.new(:guid => app_id))
    end

    def scale_to_zero(app, indices)
      instances_remaining = app.instances - indices.size

      stop_app(app)

      if instances_remaining < 0
        logger.warn "cloudcontroller.hm.negative-scale",
          :indices => indices, :app => app.guid,
          :remaining_instances => instances_remaining,
          :desired_instances => app.instances
      end
    end
  end
end
