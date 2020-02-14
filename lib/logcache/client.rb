require 'logcache/logcache_egress_services_pb'
require 'logcache/v2/envelope_pb'

module Logcache
  class Client
    MAX_LIMIT = 1000
    DEFAULT_LIMIT = 100

    def initialize(host:, port:, client_ca_path:, client_cert_path:, client_key_path:, tls_subject_name:)
      client_ca = IO.read(client_ca_path)
      client_key = IO.read(client_key_path)
      client_cert = IO.read(client_cert_path)

      @service = Logcache::V1::Egress::Stub.new(
        "#{host}:#{port}",
        GRPC::Core::ChannelCredentials.new(client_ca, client_key, client_cert),
        channel_args: { GRPC::Core::Channel::SSL_TARGET => tls_subject_name }
      )
    end

    def container_metrics(source_guid:, envelope_limit: DEFAULT_LIMIT, start_time:, end_time:)
      with_request_error_handling(source_guid) do
        service.read(
          Logcache::V1::ReadRequest.new(
            source_id: source_guid,
            start_time: start_time,
            end_time: end_time,
            limit: envelope_limit,
            descending: true,
            envelope_types: [:GAUGE]
          )
        )
      end
    end

    private

    def with_request_error_handling(source_guid, &blk)
      tries ||= 3
      yield
    rescue => e
      if (tries -= 1) > 0
        sleep 0.1
        retry
      end

      if e.is_a?(GRPC::BadStatus) && e.to_status.code == 14
        logger.warn("rescuing GRPC Unavailable error: #{e.to_status}")

        return EmptyEnvelope.new(source_guid)
      end

      raise e
    end

    def logger
      @logger ||= Steno.logger('cc.logcache.client')
    end

    attr_reader :service
  end

  class EmptyEnvelope
    def initialize(source_guid)
      @empty_envelope = Loggregator::V2::Envelope.new(
        timestamp: Time.now.to_i,
        source_id: source_guid,
        gauge: Loggregator::V2::Gauge.new(
          metrics: {
            'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 0),
            'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 0),
            'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 0),
          }
        ),
        instance_id: '0',
        tags: {
            'source_id' => source_guid,
        }
      )
    end

    def envelopes
      Loggregator::V2::EnvelopeBatch.new(batch: [self.empty_envelope])
    end

    attr_accessor :empty_envelope
  end
end
