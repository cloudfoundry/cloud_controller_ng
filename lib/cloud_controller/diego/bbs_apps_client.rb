module VCAP::CloudController
  module Diego
    class BbsAppsClient
      def initialize(client)
        @client = client
      end

      def desire_app(lrp)
        logger.info('desire.app.request', process_guid: lrp.process_guid)

        handle_diego_errors(lrp.process_guid) do
          response = @client.desire_lrp(lrp)
          logger.info('desire.app.response', process_guid: lrp.process_guid, error: response.error)

          runner_invalid_request!(response.error.message) if response.error.try(:type) == ::Diego::Bbs::Models::Error::Type::InvalidRequest
          return response if response.error.try(:type) == ::Diego::Bbs::Models::Error::Type::ResourceConflict

          response
        end
      end

      def update_app(process_guid, lrp_update)
        logger.info('update.app.request', process_guid: process_guid)

        handle_diego_errors(process_guid) do
          response = @client.update_desired_lrp(process_guid, lrp_update)
          logger.info('update.app.response', process_guid: process_guid, error: response.error)

          runner_invalid_request!(response.error.message) if response.error.try(:type) == ::Diego::Bbs::Models::Error::Type::InvalidRequest
          return response if response.error.try(:type) == ::Diego::Bbs::Models::Error::Type::ResourceConflict

          response
        end
      end

      def get_app(process_guid)
        logger.info('get.app.request', process_guid: process_guid)

        result = handle_diego_errors(process_guid) do
          response = @client.desired_lrp_by_process_guid(process_guid)
          logger.info('get.app.response', process_guid: process_guid, error: response.error)

          if response.error
            return nil if response.error.type == ::Diego::Bbs::Models::Error::Type::ResourceNotFound
          end

          response
        end

        result.desired_lrp
      end

      def stop_app(process_guid)
        logger.info('stop.app.request', process_guid: process_guid)
        handle_diego_errors(process_guid) do
          response = @client.remove_desired_lrp(process_guid)
          logger.info('stop.app.response', process_guid: process_guid, error: response.error)

          if response.error
            return nil if response.error.type == ::Diego::Bbs::Models::Error::Type::ResourceNotFound
          end

          response
        end
      end

      def stop_index(process_guid, index)
        logger.info('stop.index.request', process_guid: process_guid, index: index)
        actual_lrp_key = ::Diego::Bbs::Models::ActualLRPKey.new(process_guid: process_guid, index: index, domain: APP_LRP_DOMAIN)
        handle_diego_errors(process_guid) do
          response = @client.retire_actual_lrp(actual_lrp_key)
          logger.info('stop.index.response', process_guid: process_guid, index: index, error: response.error)

          if response.error
            return nil if response.error.type == ::Diego::Bbs::Models::Error::Type::ResourceNotFound
          end

          response
        end
      end

      def fetch_scheduling_infos
        logger.info('fetch.scheduling.infos.request')

        handle_diego_errors do
          response = @client.desired_lrp_scheduling_infos(APP_LRP_DOMAIN)
          logger.info('fetch.scheduling.infos.response', error: response.error)
          response
        end.desired_lrp_scheduling_infos
      end

      def bump_freshness
        logger.info('bump.freshness.request')

        handle_diego_errors do
          response = @client.upsert_domain(domain: APP_LRP_DOMAIN, ttl: APP_LRP_DOMAIN_TTL)
          logger.info('bump.freshness.response', error: response.error)
          response
        end
      end

      private

      def handle_diego_errors(process_guid=nil)
        begin
          response = yield
        rescue ::Diego::Error => e
          error_message = process_guid.nil? ? e : "Process Guid: #{process_guid}: #{e}"
          raise CloudController::Errors::ApiError.new_from_details('RunnerUnavailable', error_message)
        end

        if response.error
          error_message = process_guid.nil? ? response.error.message : "Process Guid: #{process_guid}: #{response.error.message}"
          raise CloudController::Errors::ApiError.new_from_details('RunnerError', error_message)
        end

        response
      end

      def runner_invalid_request!(message)
        raise CloudController::Errors::ApiError.new_from_details('RunnerInvalidRequest', message)
      end

      def logger
        @logger ||= Steno.logger('cc.bbs.apps_client')
      end
    end
  end
end
