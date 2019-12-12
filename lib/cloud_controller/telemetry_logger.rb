require 'digest'
require 'json'

module VCAP::CloudController
  class TelemetryLogger
    class << self
      def init(path)
        @telemetry_log_path = path
        @logger = ActiveSupport::Logger.new(@telemetry_log_path)
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

      def emit(event_name, entries, raw_entries={})
        resp = {
          'telemetry-source' => 'cloud_controller_ng',
          'telemetry-time' => Time.now.to_datetime.rfc3339,
          event_name => raw_entries.merge(anonymize(entries)),
        }
        logger.info(JSON.generate(resp))
      end

      attr_reader :logger

      def anonymize(entries)
        entries.transform_values { |v| Digest::SHA256.hexdigest(v) }
      end
    end
  end
end
