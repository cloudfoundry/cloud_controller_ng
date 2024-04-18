require 'jobs/wrapping_job'
require 'presenters/error_presenter'
require 'opentelemetry/sdk'
require 'opentelemetry-propagator-b3'

module VCAP::CloudController
  module Jobs
    class LoggingContextJob < WrappingJob
      attr_reader :request_id

      def initialize(handler, request_id, carrier)
        super(handler)
        @request_id = request_id
        @carrier = carrier
      end

      def perform
        tracer = OpenTelemetry.tracer_provider.tracer('cloud_controller_worker')
        context = OpenTelemetry::Propagator::B3::Single::TextMapPropagator.new.extract(@carrier)

        begin
          span = tracer.start_span("Delayed_job", with_parent: context)
          OpenTelemetry::Trace.with_span(span) do
            span.set_attribute('X-Vcap-Request-Id', @request_id)
            begin
              with_request_id_set do
                logger.info("about to run job #{wrapped_handler.class.name}")
                super
              end
            rescue CloudController::Blobstore::BlobstoreError => e
              raise CloudController::Errors::ApiError.new_from_details('BlobstoreError', e.message)
            end
          end
        rescue Exception => e # rubocop:disable Lint/RescueException
          span&.record_exception(e)
          raise e
        ensure
          span&.finish
        end

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
