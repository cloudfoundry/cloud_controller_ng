require 'cf-copilot'

module VCAP::CloudController
  class ProcessRouteHandler
    def initialize(process, runners = nil)
      @process = process

      @runners = runners || CloudController::DependencyLocator.instance.runners
    end

    def update_route_information
      return unless @process

      with_transaction do
        @process.lock!

        if @process.diego?
          @process.update(updated_at: Sequel::CURRENT_TIMESTAMP)
        elsif @process.dea?
          @process.set_new_version
          @process.save_changes
        end

        @process.db.after_commit do
          notify_copilot_of_route_update
          notify_backend_of_route_update
        end
      end
    end

    def notify_copilot_of_route_update
      logger.info("notifying copilot now")
      copilot_client = CloudController::DependencyLocator.instance.copilot_client
      route_guid = 'some-guid'
      host = 'some-host'
      # call copilot sdk
      logger.info("got a copilot client #{copilot_client.inspect}")
      logger.info("upserting route in copilot")
      copilot_client.upsert_route(
          guid: route_guid,
          host: host,
      )
      logger.info("success upserting route in copilot")
      capi_process_guid = 'some-capi-process-guid'
      logger.info("mapping route in copilot")
      copilot_client.map_route(
          capi_process_guid: capi_process_guid,
          route_guid: route_guid
      )
      logger.info("success mapping route in copilot")
    rescue => e
      logger.error("failed communicating with copilot server: #{e.message}")
    end

    def notify_backend_of_route_update
      @runners.runner_for_process(@process).update_routes if @process && @process.staged? && @process.started?
    rescue Diego::Runner::CannotCommunicateWithDiegoError => e
      logger.error("failed communicating with diego backend: #{e.message}")
    end

    private

    def with_transaction
      if @process.db.in_transaction?
        yield
      else
        @process.db.transaction do
          yield
        end
      end
    end

    def logger
      @logger ||= Steno.logger('cc.process_route_handler')
    end
  end
end
