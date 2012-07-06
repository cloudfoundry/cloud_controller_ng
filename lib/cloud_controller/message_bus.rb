# Copyright (c) 2012-2012 VMware, Inc.

require "nats/client"
require "vcap/component"
require "cloud_controller/json_patch"

module VCAP::CloudController::MessageBus
  class << self
    attr_reader :config
    attr_reader :nats

    def configure(config)
      @config = config
      @nats = config[:nats] || NATS
    end
  end

  def self.register_components
    # hook up with NATS
    # TODO: put useful metrics in varz
    # TODO: subscribe to the two DEA channels
    EM.schedule do
      nats.start(:uri => config[:nats_uri]) do
        VCAP::Component.register(
          :type => 'CloudController',
          :host => VCAP.local_ip,
          :index => config[:index],
          :config => config,
          # leaving the varz port / user / pwd blank to be random
        )
      end
    end
  end

  def self.register_routes
    EM.schedule do
      # TODO: blacklist api2 in legacy CC
      # TODO: Yajl should probably also be injected
      router_register_message = Yajl::Encoder.encode({
        :host => VCAP.local_ip,
        :port => config[:port],
        :uris => [config[:external_domain]],
        :tags => {:component => "CloudController" },
      })
      nats.publish("router.register", router_register_message)
      # Broadcast when a router restarts
      nats.subscribe("router.start") do
        nats.publish("router.register", router_register_message)
      end
    end
  end
end
