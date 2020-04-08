require 'digest'
require 'json'

module VCAP::CloudController
  class TelemetryLogger
    INTEGER_FIELDS = %w(instance-count memory-in-mb disk-in-mb).freeze
    class << self
      def init(logger)
        @logger = logger
      end

      def v2_emit(event_name, entries, raw_entries={})
        emit(event_name, entries, { 'api-version' => 'v2' }.merge(raw_entries))
      end

      def v3_emit(event_name, entries, raw_entries={})
        emit(event_name, entries, { 'api-version' => 'v3' }.merge(raw_entries))
      end

      def internal_emit(event_name, entries, raw_entries={})
        emit(event_name, entries, { 'api-version' => 'internal' }.merge(raw_entries))
      end

      private

      attr_reader :logger

      def emit(event_name, entries, raw_entries={})
        converted_entries = raw_entries.merge(raw_entries.select { |k, v|
          INTEGER_FIELDS.include?(k)
        }.transform_values(&:to_i))

        resp = {
          'telemetry-source' => 'cloud_controller_ng',
          'telemetry-time' => Time.now.to_datetime.rfc3339,
          event_name => converted_entries.merge(anonymize(entries)),
        }
        logger.info(JSON.generate(resp))
      end

      def anonymize(entries)
        entries.transform_values { |v| Digest::SHA256.hexdigest(v) }
      end
    end
  end
end
