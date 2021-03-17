module VCAP
  module Request
    HEADER_NAME = 'X-VCAP-Request-ID'.freeze
    HEADER_BROKER_API_VERSION = 'X-Broker-Api-Version'.freeze
    HEADER_API_INFO_LOCATION = 'X-Api-Info-Location'.freeze
    HEADER_BROKER_API_ORIGINATING_IDENTITY = 'X-Broker-Api-Originating-Identity'.freeze
    HEADER_BROKER_API_REQUEST_IDENTITY = 'X-Broker-API-Request-Identity'.freeze
    HEADER_ZIPKIN_B3_TRACEID = 'X-B3-TraceId'.freeze
    HEADER_ZIPKIN_B3_SPANID = 'X-B3-SpanId'.freeze

    class << self
      def current_id=(request_id)
        Thread.current[:vcap_request_id] = request_id
        if request_id.nil?
          Steno.config.context.data.delete('request_guid')
        else
          Steno.config.context.data['request_guid'] = request_id
        end
      end

      def current_id
        Thread.current[:vcap_request_id]
      end

      def b3_trace_id=(trace_id)
        Thread.current[:b3_trace_id] = trace_id
        if trace_id.nil?
          Steno.config.context.data.delete('b3_trace_id')
        else
          Steno.config.context.data['b3_trace_id'] = trace_id
        end
      end

      def b3_trace_id
        Thread.current[:b3_trace_id]
      end

      def b3_span_id=(span_id)
        Thread.current[:b3_span_id] = span_id
        if span_id.nil?
          Steno.config.context.data.delete('b3_span_id')
        else
          Steno.config.context.data['b3_span_id'] = span_id
        end
      end

      def b3_span_id
        Thread.current[:b3_span_id]
      end
    end
  end
end
