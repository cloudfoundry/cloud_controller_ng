require 'presenters/error_presenter'

module VCAP::CloudController
  module Jobs
    class ExceptionCatchingJob < VCAP::CloudController::Jobs::CCJob
      attr_accessor :handler

      def initialize(handler)
        @handler = handler
      end

      def perform
        handler.perform
      end

      def error(job, e)
        error_presenter = ErrorPresenter.new(e)
        log_error(error_presenter)
        save_error(error_presenter, job)
      end

      def max_attempts
        handler.max_attempts
      end

      def reschedule_at(time, attempts)
        handler.reschedule_at(time, attempts)
      end

      private

      def save_error(error_presenter, job)
        job.cf_api_error = YAML.dump(error_presenter.error_hash)
        job.save
      end

      def log_error(error_presenter)
        if error_presenter.client_error?
          logger.info(error_presenter.log_message)
        else
          logger.error(error_presenter.log_message)
        end
      end

      def logger
        Steno.logger('cc.background')
      end
    end
  end
end
