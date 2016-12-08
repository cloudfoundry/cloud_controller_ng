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

          return response if response.error.try(:type) == ::Diego::Bbs::Models::Error::Type::ResourceConflict

          response
        end
      end

      def update_app(process_guid, lrp_update)
        logger.info('update.app.request', process_guid: process_guid)

        handle_diego_errors do
          response = @client.update_desired_lrp(process_guid, lrp_update)
          logger.info('update.app.response', process_guid: process_guid, error: response.error)

          return response if response.error.try(:type) == ::Diego::Bbs::Models::Error::Type::ResourceConflict

          response
        end
      end

      def app_exists?(process_guid)
        logger.info('app.exists.request', process_guid: process_guid)

        handle_diego_errors do
          response = @client.desired_lrp_by_process_guid(process_guid)
          logger.info('app.exists.response', process_guid: process_guid, error: response.error)

          if response.error
            return false if response.error.type == ::Diego::Bbs::Models::Error::Type::ResourceNotFound
          end

          response
        end

        true
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
        @logger ||= Steno.logger('cc.bbs.apps_client')
      end
    end
  end
end
