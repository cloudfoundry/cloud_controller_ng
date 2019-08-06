require 'digest'
require 'json'

module VCAP::CloudController
  class TelemetryLogger
    class << self
      def init(path)
        @telemetry_log_path = path
        @logger = ActiveSupport::Logger.new(@telemetry_log_path)
      end

      def emit(event_name, event)
        resp = {
          'telemetry-source' => 'cloud_controller_ng',
          'telemetry-time' => Time.now.to_datetime.rfc3339,
          event_name => anonymize(event),
        }

        logger.info(JSON.generate(resp))
      end

      private

      attr_reader :logger

      def anonymize(raw_event)
        raw_event.each_with_object({}) do |(key, body), anonymized_event|
          anonymized_event[key] = if body.fetch('raw', false)
                                    body['value']
                                  else
                                    Digest::SHA256.hexdigest(body['value'])
                                  end
        end
      end
    end
  end
end
