require 'logcache/egress_services_pb'
require 'loggregator-api/v2/envelope_pb'
require 'logcache/promql_pb'
require 'logcache/promql_services_pb'

module Logcache
  class Client
    MAX_LIMIT = 1000
    DEFAULT_LIMIT = 100

    def initialize(host:, port:, client_ca_path:, client_cert_path:, client_key_path:, tls_subject_name:)
      if client_ca_path
        client_ca = IO.read(client_ca_path)
        client_key = IO.read(client_key_path)
        client_cert = IO.read(client_cert_path)

        @promql_service = Logcache::V1::PromQLQuerier::Stub.new(
          "#{host}:#{port}",
          GRPC::Core::ChannelCredentials.new(client_ca, client_key, client_cert),
          channel_args: { GRPC::Core::Channel::SSL_TARGET => tls_subject_name },
          timeout: 10
        )

        @service = Logcache::V1::Egress::Stub.new(
          "#{host}:#{port}",
          GRPC::Core::ChannelCredentials.new(client_ca, client_key, client_cert),
          channel_args: { GRPC::Core::Channel::SSL_TARGET => tls_subject_name },
          timeout: 10
        )
      else
        @promql_service = Logcache::V1::PromQLQuerier::Stub.new(
          "#{host}:#{port}",
          :this_channel_is_insecure,
          timeout: 10
        )

        @service = Logcache::V1::Egress::Stub.new(
          "#{host}:#{port}",
          :this_channel_is_insecure,
          timeout: 10
        )
      end
    end

    def container_metrics(source_guid:, start_time:, end_time:, envelope_limit: DEFAULT_LIMIT)
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

    # Fetches all relevant metrics in parallel for the given source_ids
    # @param source_ids [Array<String>] List of source IDs
    # @param time [String] The time for the instant query (must be a unix timestamp)
    # @return [Hash{String=>Logcache::V1::PromQL::InstantQueryResult}] Hash with metric names as keys and their respective query results as values
    def fetch_all_metrics_parallel(source_ids, time=unix_timestamp)
      logger.info('fetching all metrics in parallel using PromQL', source_ids:)
      metrics = %w[memory cpu cpu_entitlement disk log_rate disk_quota memory_quota log_rate_limit]
      threads = {}
      results = {}

      metrics.each do |metric|
        threads[metric] = Thread.new do
          method = "fetch_#{metric}_metrics"
          results[metric] = send(method, source_ids, time)
        rescue StandardError => e
          results[metric] = e
        end
      end

      threads.each_value(&:join)
      results
    end

    private

    # Fetches the "memory" metric for the given source_ids
    # @param source_ids [Array<String>] List of source IDs
    # @param time [String] The time for the instant query (must be a unix timestamp)
    # @return [Logcache::V1::PromQL::InstantQueryResult] The result of the query
    def fetch_memory_metrics(source_ids, time=unix_timestamp)
      query = build_promql_query(source_ids, 'memory')
      request = Logcache::V1::PromQL::InstantQueryRequest.new(query:, time:)
      promql_service.instant_query(request)
    end

    # Fetches the "cpu" metric for the given source_ids
    def fetch_cpu_metrics(source_ids, time=unix_timestamp)
      query = build_promql_query(source_ids, 'cpu')
      request = Logcache::V1::PromQL::InstantQueryRequest.new(query:, time:)
      promql_service.instant_query(request)
    end

    # Fetches the "cpu_entitlement" metric for the given source_ids
    def fetch_cpu_entitlement_metrics(source_ids, time=unix_timestamp)
      query = build_promql_query(source_ids, 'cpu_entitlement')
      request = Logcache::V1::PromQL::InstantQueryRequest.new(query:, time:)
      promql_service.instant_query(request)
    end

    # Fetches the "disk" metric for the given source_ids
    def fetch_disk_metrics(source_ids, time=unix_timestamp)
      query = build_promql_query(source_ids, 'disk')
      request = Logcache::V1::PromQL::InstantQueryRequest.new(query:, time:)
      promql_service.instant_query(request)
    end

    # Fetches the "log_rate" metric for the given source_ids
    def fetch_log_rate_metrics(source_ids, time=unix_timestamp)
      query = build_promql_query(source_ids, 'log_rate')
      request = Logcache::V1::PromQL::InstantQueryRequest.new(query:, time:)
      promql_service.instant_query(request)
    end

    # Fetches the "disk_quota" metric for the given source_ids
    def fetch_disk_quota_metrics(source_ids, time=unix_timestamp)
      query = build_promql_query(source_ids, 'disk_quota')
      request = Logcache::V1::PromQL::InstantQueryRequest.new(query:, time:)
      promql_service.instant_query(request)
    end

    # Fetches the "memory_quota" metric for the given source_ids
    def fetch_memory_quota_metrics(source_ids, time=unix_timestamp)
      query = build_promql_query(source_ids, 'memory_quota')
      request = Logcache::V1::PromQL::InstantQueryRequest.new(query:, time:)
      promql_service.instant_query(request)
    end

    # Fetches the "log_rate_limit" metric for the given source_ids
    def fetch_log_rate_limit_metrics(source_ids, time=unix_timestamp)
      query = build_promql_query(source_ids, 'log_rate_limit')
      request = Logcache::V1::PromQL::InstantQueryRequest.new(query:, time:)
      promql_service.instant_query(request)
    end

    # Builds the PromQL query string for the "memory" metric
    # @param source_ids [Array<String>] List of source IDs
    # @return [String] The PromQL query string
    def build_promql_query(source_ids, metric_name)
      source_id_filter = source_ids.join('|')
      "#{metric_name}{source_id=~\"#{source_id_filter}\"}"
    end

    def with_request_error_handling(source_guid)
      tries ||= 3
      start_time = Time.now

      result = yield
      time_taken_in_ms = ((Time.now - start_time) * 1000).to_i # convert to milliseconds to get more precise information
      logger.info('logcache.response',
                  { source_id: source_guid,
                    time_taken_in_ms: time_taken_in_ms })
      result
    rescue StandardError => e
      raise CloudController::Errors::ApiError.new_from_details('ServiceUnavailable', 'Connection to Log Cache timed out') if e.is_a?(GRPC::DeadlineExceeded)

      if (tries -= 1) > 0
        sleep 0.1
        retry
      end

      raise e
    end

    def logger
      @logger ||= Steno.logger('cc.logcache.client')
    end

    def unix_timestamp
      Time.now.utc.to_i.to_s
    end

    attr_reader :service, :promql_service
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
            'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 0)
          }
        ),
        instance_id: '0',
        tags: {
          'source_id' => source_guid
        }
      )
    end

    def envelopes
      Loggregator::V2::EnvelopeBatch.new(batch: [empty_envelope])
    end

    attr_accessor :empty_envelope
  end
end
