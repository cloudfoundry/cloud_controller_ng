require 'jobs/wrapping_job'
require 'presenters/error_presenter'
require 'controllers/v3/mixins/errors_helper'

module VCAP::CloudController
  module Jobs
    class LoggingContextJob < WrappingJob
      include ErrorsHelper

      attr_reader :request_id

      def initialize(handler, request_id, api_version)
        super(handler)
        @request_id = request_id
        @api_version = api_version
      end

      def perform
        with_request_id_set do
          logger.info("about to run job #{wrapped_handler.class.name}")
          super
        end
      end

      def error(job, exception)
        exception = translate_error(exception)
        error_presenter = if @api_version == VCAP::Request::API_VERSION_V3
                            ErrorPresenter.new(exception, false, V3ErrorHasher.new(exception))
                          else
                            ErrorPresenter.new(exception)
                          end
        log_error(error_presenter, job)
        save_error(error_presenter, job)
        super(job, exception)
      end

      private

      def translate_error(exception)
        case exception
        when CloudController::Blobstore::BlobstoreError
          blobstore_error(exception.message)
        when VCAP::CloudController::AppDelete::SubResourceError
          compound_error(exception.underlying_errors.map { |err| unprocessable(err.message) })
        else
          exception
        end
      end

      def save_error(error_presenter, job)
        job.cf_api_error = YAML.dump(error_presenter.to_hash)
        deprioritize_job(job)
        job.save
      end

      def log_error(error_presenter, job)
        with_request_id_set do
          if error_presenter.client_error?
            logger.info(error_presenter.log_message, job_guid: job.guid)
          else
            logger.error(error_presenter.log_message, job_guid: job.guid)
          end
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

      def with_request_id_set(&block)
        current_request_id         = ::VCAP::Request.current_id
        ::VCAP::Request.current_id = @request_id
        yield
      ensure
        ::VCAP::Request.current_id = current_request_id
      end
    end
  end
end
