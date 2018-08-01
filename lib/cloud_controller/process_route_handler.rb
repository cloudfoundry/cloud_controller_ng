module VCAP::CloudController
  class ProcessRouteHandler
    def initialize(process, runners=nil)
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

        @process.db.after_commit { notify_backend_of_route_update }
      end
    end

    def notify_backend_of_route_update
      @runners.runner_for_app(@process).update_routes if @process && @process.staged? && @process.started?
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
