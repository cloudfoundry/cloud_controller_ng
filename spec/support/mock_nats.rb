class MockNATS
  class << self
    attr_accessor :client

    def start(*args)
      self.client = new
    end
  end
end


require "nats/client"
require "support/mock_class"

# Defined specifically for NatsClientMock
class NatsInstance
  # NATS is actually a module which gets made into a class
  # and then instantiated by one of the EM.connect* methods
  include NATS
end

MockClass.define(:NatsClientMock, NatsInstance) do
  overrides :initialize do |options|
    @options = options
    @subscriptions = Hash.new { |h, k| h[k] = [] }
  end

  overrides :subscribe do |subject, opts={}, &callback|
    @subscriptions[subject] << callback
    callback # Consider block a subscription id
  end

  overrides :unsubscribe do |sid, opt_max=nil|
    @subscriptions.each do |_, blks|
      blks.delete(sid)
    end
  end

  overrides :publish do |subject, msg=nil, opt_reply=nil, &blk|
    @subscriptions[subject].each do |blk|
      blk.call(msg, opt_reply)
    end
  end

  overrides :request do |subject, data=nil, opts={}, &cb|
    @last_inbox = nil

    if cb
      @last_inbox = "nats_mock_request_#{Time.now.nsec}"
      subscribe(@last_inbox, &cb)
    end

    # Publish messages to everyone
    publish(subject, data, @last_inbox)

    # cb is acting as subscription id
    cb
  end

  overrides :timeout do |sid, timeout, opts={}, &callback|
    # noop
  end

  add :reply_to_last_request do |subject, data, options={}|
    raise ArgumentError, "last_inbox must not be nil" unless @last_inbox

    @subscriptions[@last_inbox].each do |blk|
      if options[:invalid_json]
        blk.call("invalid-json")
      else
        blk.call(Yajl::Encoder.encode(data))
      end
    end
  end
end
