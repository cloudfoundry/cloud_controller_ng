require 'jobs/wrapping_job'
require 'presenters/error_presenter'
require 'opentelemetry/sdk'

module VCAP::CloudController
  module Jobs
    class LoggingContextJob < WrappingJob
      attr_reader :request_id

      def initialize(handler, request_id)
        super(handler)
        @request_id = request_id
      end

      def perform
        with_request_id_set do
          logger.info("about to run job #{wrapped_handler.class.name}")
          super
        end
      rescue CloudController::Blobstore::BlobstoreError => e
        raise CloudController::Errors::ApiError.new_from_details('BlobstoreError', e.message)
      end

      def success(job)
        with_request_id_set do
          super(job)
        end
      end

      def error(job, e)
        with_request_id_set do
          error_presenter = if e.instance_of?(CloudController::Errors::CompoundError)
                              ErrorPresenter.new(e, false, V3ErrorHasher.new(e))
                            else
                              ErrorPresenter.new(e)
                            end
          log_error(error_presenter, job)
          save_error(error_presenter, job)
          super(job, e)
        end
      end

      private

      def save_error(error_presenter, job)
        job.cf_api_error = YAML.dump(error_presenter.to_hash)
        deprioritize_job(job)
        job.save
      end

      def log_error(error_presenter, job)
        if error_presenter.client_error?
          logger.info(error_presenter.log_message, job_guid: job.guid)
        else
          logger.error(error_presenter.log_message, job_guid: job.guid)
        end
      end

      def deprioritize_job(job)
        if job.priority < 0
          job.priority = 0
        elsif job.priority == 0
          job.priority = 1
        else
          job.priority *= 2
        end
      end

      def logger
        Steno.logger('cc.background')
      end

      def with_request_id_set
        current_request_id         = ::VCAP::Request.current_id
        ::VCAP::Request.current_id = @request_id
        yield
      ensure
        ::VCAP::Request.current_id = current_request_id
      end
    end
  end
end
