module VCAP::CloudController
  module Diego
    class StagingResponse
      def initialize(payload)
        validate(payload)
        @payload = payload
      end

      def execution_metadata
        @payload[:execution_metadata]
      end

      def detected_start_command
        @payload[:detected_start_command]
      end

      def lifecycle_data
        @payload[:lifecycle_data]
      end

      def error?
        @payload[:error] != nil
      end

      def error_id
        @payload[:error][:id] if error?
      end

      def error_message
        @payload[:error][:message] if error?
      end

      private

      def validate(payload)
        raise Errors::ApiError.new_from_details('InvalidRequest', payload) unless payload.is_a? Hash

        failure_schema.validate(payload) if payload.key?(:error)
        success_schema.validate(payload) unless payload.key?(:error)
      rescue Membrane::SchemaValidationError => e
        logger.error('diego.staging.invalid-response', payload: payload, error: e.to_s)
        raise Errors::ApiError.new_from_details('InvalidRequest', payload)
      end

      def logger
        @logger ||= Steno.logger('cc.stager')
      end

      def failure_schema
        @failure_schema ||= Membrane::SchemaParser.parse do
          {
            error: {
              id: String,
              message: String,
            }
          }
        end
      end

      def success_schema
        @success_schema ||= Membrane::SchemaParser.parse do
          {
            execution_metadata: String,
            optional(:detected_start_command) => {
              web: String,
            },
            optional(:lifecycle_data) => Hash,
          }
        end
      end
    end
  end
end
