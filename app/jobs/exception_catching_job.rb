require 'presenters/error_presenter'

module VCAP::CloudController
  module Jobs
    class ExceptionCatchingJob < WrappingJob
      def perform
        super
      rescue CloudController::Blobstore::BlobstoreError => e
        raise CloudController::Errors::ApiError.new_from_details('BlobstoreError', e.message)
      end

      def error(job, e)
        error_presenter = ErrorPresenter.new(e)
        log_error(error_presenter)
        save_error(error_presenter, job)
        super(job, e)
      end

      private

      def save_error(error_presenter, job)
        job.cf_api_error = YAML.dump(error_presenter.to_hash)
        deprioritize_job(job)
        job.save
      end

      def log_error(error_presenter)
        if error_presenter.client_error?
          logger.info(error_presenter.log_message)
        else
          logger.error(error_presenter.log_message)
        end
      end

      def deprioritize_job(job)
        if job.priority == 0
          job.priority = 1
        else
          job.priority *= 2
        end
      end

      def logger
        Steno.logger('cc.background')
      end
    end
  end
end
