module VCAP
  class Loggregator
    class << self
      attr_accessor :emitter, :logger

      def emit(app_id, message)
        emitter.emit(app_id, message, generate_tags(app_id)) if emitter
      rescue => e
        logger.error('loggregator_emitter.emit.failed', app_id: app_id, message: message, error: e)
      end

      def emit_error(app_id, message)
        emitter.emit_error(app_id, message, generate_tags(app_id)) if emitter
      rescue => e
        logger.error('loggregator_emitter.emit_error.failed', app_id: app_id, message: message, error: e)
      end

      private

      def generate_tags(app_id)
        app, space, org = VCAP::CloudController::AppFetcher.new.fetch(app_id)
        if app.nil?
          return {
            app_id: app_id,
            app_name: '',
            space_id: '',
            space_name: '',
            organization_id: '',
            organization_name: ''
          }
        end

        {
          app_id: app.guid,
          app_name: app.name,
          space_id: space.guid,
          space_name: space.name,
          organization_id: org.guid,
          organization_name: org.name
        }
      end
    end
  end
end
