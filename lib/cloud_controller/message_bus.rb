# Copyright (c) 2012-2012 VMware, Inc.

require "nats/client"
require "vcap/component"
require "cloud_controller/json_patch"

class VCAP::CloudController::MessageBus
  class << self
    attr_reader :instance

    def instance=(instance)
      raise ArgumentError, "instance must not be nil" unless instance
      @instance = instance
    end
  end

  attr_reader :config, :nats, :subscriptions

  def initialize(config)
    @config = config
    @nats = config[:nats] || NATS
    @subscriptions = {}
  end

  def nats_options
    { :uri => config[:nats_uri] }
  end

  def register_components
    # TODO: put useful metrics in varz
    # TODO: subscribe to the two DEA channels
    EM.error_handler do |e|
      if e.class == NATS::ConnectError
        log.warn("NATS connection failed. Starting nats recovery")
        start_nats_recovery
      else
        raise e
      end
    end

    EM.schedule do
      nats.start(nats_options) do
        VCAP::Component.register(
          :type => 'CloudController',
          :host => @config[:bind_address],
          :index => config[:index],
          :config => config,
          # leaving the varz port / user / pwd blank to be random
        )
      end
    end
  end

  def start_nats_recovery
    EM.defer do
      unless nats.connected?
        nats.on_error do
          start_nats_recovery
        end
        nats.wait_for_server(nats_options[:uri])
        nats.connect(nats_options) do
          register_routes

          @subscriptions.each do |subject, options|
            subscribe(subject, options[0], &options[1])
          end
        end
      end
    end
  end

  def register_routes
    EM.schedule do
      # TODO: blacklist api2 in legacy CC
      # TODO: Yajl should probably also be injected
      router_register_message = Yajl::Encoder.encode({
        :host => @config[:bind_address],
        :port => config[:port],
        :uris => config[:external_domain],
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
  def subscribe(subject, opts = {}, &blk)
    @subscriptions[subject] = [opts, blk]

    subscribe_on_reactor(subject, opts) do |payload, inbox|
      EM.defer do
        begin
          # OK so we're always calling with arity two
          # NATS does a switch on blk.arity
          # we might do it if we are propelled to supply a lambda here...
          blk.yield(payload, inbox)
        rescue => e
          logger.error "exception processing: '#{subject}' '#{payload}'"
        end
      end
    end
  end

  def publish(subject, message = nil)
    EM.schedule do
      nats.publish(subject, message)
    end
  end

  def request(subject, data = nil, opts = {})
    opts ||= {}
    expected = opts[:expected] || 1
    timeout = opts[:timeout] || -1

    return [] if expected <= 0

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

  def subscribe_on_reactor(subject, opts = {}, &blk)
    EM.schedule do
      nats.subscribe(subject, opts) do |msg, inbox|
        process_message(msg, inbox, &blk)
      end
    end
  end

  def process_message(msg, inbox, &blk)
    payload = Yajl::Parser.parse(msg, :symbolize_keys => true)
    blk.yield(payload, inbox)
  rescue => e
    logger.error "exception processing: '#{msg}' '#{e}'"
  end

  def logger
    @logger ||= Steno.logger("cc.mbus")
  end
end
