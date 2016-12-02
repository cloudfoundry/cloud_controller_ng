module VCAP::CloudController
  module Diego
    class BbsAppsClient
      def initialize(client)
        @client = client
      end

      def desire_app(lrp)
        logger.info('desire.app.request', process_guid: lrp.process_guid)

        handle_diego_errors do
          response = @client.desire_lrp(lrp)
          logger.info('desire.app.response', process_guid: lrp.process_guid, error: response.error)
          response
        end
      end

      private

      def handle_diego_errors
        begin
          response = yield
        rescue ::Diego::Error => e
          raise CloudController::Errors::ApiError.new_from_details('RunnerUnavailable', e)
        end

        if response.error
          raise CloudController::Errors::ApiError.new_from_details('RunnerError', response.error.message)
        end
      end

      def logger
        @logger ||= Steno.logger('cc.bbs.task_client')
      end
    end
  end
end
