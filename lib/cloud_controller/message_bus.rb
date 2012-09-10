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
    em_schedule do
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
    em_schedule do
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

  # Subscribe to a subject on the message bus.
  # The provided block is called on a thread
  #
  # @params [String] subject the subject to subscribe to
  # @params [Hash] opts nats subscribe options
  #
  # @yield [payload, inbox] callback invoked when a message is posted on the subject
  # @yieldparam [String] payload the message posted on the channel
  # @yieldparam [optional, String] inbox an optional "reply to" subject, nil if not requested
  def self.subscribe(subject, opts = {}, &blk)
    subscribe_on_reactor(subject, opts) do |payload, inbox|
      # blk is ultimately a call to process_message, so we won't pass
      # exceptions to EM
      EM.defer do
        # OK so we're always calling with arity two
        # NATS does a switch on blk.arity
        # we might do it if we are propelled to supply a lambda here...
        blk.yield(payload, inbox)
      end
    end
  end

  def self.subscribe_on_reactor(subject, opts = {}, &blk)
    em_schedule do
      nats.subscribe(subject, opts) do |msg, inbox|
        process_message(msg, inbox, &blk)
      end
    end
  end

  def self.publish(subject, message = nil)
    em_schedule do
      nats.publish(subject, message)
    end
  end

  def self.request(subject, data = nil, opts = {})
    opts ||= {}
    expected = opts[:expected] || 1
    timeout = opts[:timeout] || -1

    # schedule sync captures and rethrows its exceptions back to us.  They
    # won't leak into EM.
    response = EM.schedule_sync do |promise|
      results = []
      sid = nats.request(subject, data, :max => expected) do |msg|
        results << msg
        promise.deliver(results) if results.size == expected
      end

      if timeout >= 0
        nats.timeout(sid, timeout, :expected => expected) do
          promise.deliver(results)
        end
      end
    end

    response
  end

  private

  def self.process_message(msg, inbox, &blk)
    payload = Yajl::Parser.parse(msg, :symbolize_keys => true)
    blk.yield(payload, inbox)
  rescue => e
    logger.error "exception processing: '#{msg}' '#{e}'"
  end

  def self.em_schedule(&blk)
    # I'm not certain if EM will care if we throw an exception to it while
    # running in its reactor thread, but even if it is fine now, it might not
    # be in the future.  Let's make sure that we never do it.
    EM.schedule do
      begin
        blk.yield
      rescue => e
        logger.error "em_schdule exception: '#{e}'"
      end
    end
  end

  def self.logger
    @logger ||= Steno.logger("cc.mbus")
  end
end
