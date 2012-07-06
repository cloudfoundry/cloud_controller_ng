# Copyright (c) 2012-2012 VMware, Inc.

require "nats/client"
require "vcap/component"
require "cloud_controller/json_patch"

def register_components(config)
  nats = config.delete(:nats) || NATS
  # hook up with NATS
  # FIXME: index should be configurable
  # TODO: put useful metrics in varz
  # TODO: subscribe to the two DEA channels
  EM.schedule do
    nats.start(:uri => config[:nats_uri]) do
      VCAP::Component.register(:type => 'CloudController',
                               :host => VCAP.local_ip,
                               :index => config[:index],
                               :config => config,
                               # leaving the varz port / user / pwd blank to be random
                              )
    end
  end
end

def register_routes(config)
  nats = config.delete(:nats) || NATS
  EM.schedule do
    # TODO: blacklist api2 in legacy CC
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
