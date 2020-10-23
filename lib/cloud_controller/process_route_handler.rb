module VCAP::CloudController
  class ProcessRouteHandler
    def initialize(process, runners=nil)
      @process = process
      @runners = runners || CloudController::DependencyLocator.instance.runners
    end

    def update_route_information(perform_validation: true, updated_ports: false)
      return unless @process

      with_transaction do
        @process.lock!

        # `false` means do **not** update ports. `nil` is a valid value as it
        # is used to use defaults later on.
        if updated_ports == false
          updated_ports = @process.ports
        end

        @process.set(
          updated_at: ProcessModel.dataset.current_datetime,
          ports: updated_ports
        )

        raise Sequel::ValidationFailed.new(@process.errors.full_messages) if PortsPolicy.new(@process).validate

        @process.save_changes({ validate: perform_validation })
        @process.db.after_commit { notify_backend_of_route_update }
      end
    end

    def notify_backend_of_route_update
      @runners.runner_for_process(@process).update_routes if @process && @process.staged? && @process.started?
    rescue Diego::Runner::CannotCommunicateWithDiegoError => e
      logger.error("failed communicating with diego backend: #{e.message}")
    end

    private

    def with_transaction(&block)
      if @process.db.in_transaction?
        yield
      else
        @process.db.transaction(&block)
      end
    end

    def logger
      @logger ||= Steno.logger('cc.process_route_handler')
    end
  end
end
