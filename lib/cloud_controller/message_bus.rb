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

  # The provided block is called on a thread
  def self.subscribe(subject, &blk)
    subscribe_on_reactor(subject) do |payload|
      EM.defer do
        blk.yield(payload)
      end
    end
  end

  def self.subscribe_on_reactor(subject, &blk)
    EM.schedule do
      nats.subscribe(subject) do |msg|
        process_message(msg, &blk)
      end
    end
  end

  def self.publish(subject, message = nil)
    EM.schedule do
      nats.publish(subject, message)
    end
  end

  def self.timed_request(subject, data = nil, opts = {})
    expected = opts[:expected] || 1
    timeout = opts[:timeout] || 1

    type_error = "Expected '%s' to be of type: '%s' and >= 1,"
    type_error << " but received: '%s' with value: %s."

    unless expected.is_a?(Integer)
      raise ArgumentError, type_error % ['expected', Integer.to_s,
                                         expected.class, expected.to_s]
    end

    unless expected >= 1
      msg = "Expected 'expected' to be >= 1, but received: #{expected}."
      raise ArgumentError, msg
    end

    unless timeout.is_a?(Integer)
      raise ArgumentError, type_error % ['timeout', Integer.to_s,
                                         timeout.class, timeout.to_s]
    end

    unless timeout >= 0
      msg = "Expected 'timeout' to be >= 0, but received: #{timeout}."
      raise ArgumentError, msg
    end

    f = Fiber.current
    results = []
    sid = nats.request(subject, data, :max => expected) do |msg|
      results << msg
      f.resume if results.length >= expected
    end
    nats.timeout(sid, timeout, :expected => expected) { f.resume }
    Fiber.yield

    return results.slice(0, expected)
  end

  private

  def self.process_message(msg, &blk)
    payload = Yajl::Parser.parse(msg, :symbolize_keys => true)
    blk.yield(payload)
  rescue => e
    CloudController.logger.error("exception processing: '#{msg}' '#{e}'")
  end
end
