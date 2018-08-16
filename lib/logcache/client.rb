require 'logcache/logcache_egress_services_pb'

module Logcache
  class Client
    MAX_LIMIT = 1000
    DEFAULT_LIMIT = 100

    def initialize(host:, port:, client_ca_path:, client_cert_path:, client_key_path:)
      client_ca = IO.read(client_ca_path)
      client_key = IO.read(client_key_path)
      client_cert = IO.read(client_cert_path)

      @service = Logcache::V1::Egress::Stub.new(
        "#{host}:#{port}",
        GRPC::Core::ChannelCredentials.new(client_ca, client_key, client_cert),
        channel_args: { GRPC::Core::Channel::SSL_TARGET => 'log_cache' }
      )
    end

    def container_metrics(source_guid:, envelope_limit: DEFAULT_LIMIT)
      service.read(
        Logcache::V1::ReadRequest.new(
          source_id: source_guid,
          limit: envelope_limit,
          descending: true,
          envelope_types: [:GAUGE]
        )
      )
    end

    private

    attr_reader :service
  end
end
