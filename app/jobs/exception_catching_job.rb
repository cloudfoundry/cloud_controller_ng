module VCAP::CloudController
  module Jobs
    class ExceptionCatchingJob < Struct.new(:handler)
      def perform
        handler.perform
      end

      def error(job, e)
        error_presenter = ErrorPresenter.new(e)
        log_error(error_presenter)
        save_error(error_presenter, job)
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
        Steno.logger("cc.background")
      end
    end
  end
end