module VCAP::CloudController::Diego
  class ServiceRegistry
    TPS_SUBJECT = 'service.announce.tps'.freeze

    def initialize(message_bus)
      @message_bus  = message_bus
      @tps_services = {}
    end

    def run!
      message_bus.subscribe(TPS_SUBJECT) do |msg|
        logger.info "Received tps service announcement: Address: #{msg['addr']} TTL: #{msg['ttl']}"
        set_tps_addr(msg['addr'], msg['addr'], msg['ttl'])
      end
    end

    def tps_addrs
      expire_tps_addrs
      tps_services.map { |_, val| val[:addr] }
    end

    private

    attr_accessor :tps_services
    attr_reader :message_bus

    def set_tps_addr(guid, addr, ttl)
      expires_at         = Time.now + ttl
      tps_services[guid] = { addr: addr, expires_at: expires_at }
    end

    def expire_tps_addrs
      now = Time.now
      tps_services.select! { |_, val| val[:expires_at] > now }
    end

    def logger
      @logger ||= Steno.logger('cc.diego.service_registry')
    end
  end
end