require 'jobs/wrapping_job'
require 'presenters/error_presenter'

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
          logger.info("about to run job #{wrapped_handler.inspect}")
          super
        end
      rescue CloudController::Blobstore::BlobstoreError => e
        raise CloudController::Errors::ApiError.new_from_details('BlobstoreError', e.message)
      end

      def error(job, e)
        #require 'pp'
        #idx = caller.find_index{|s| s['spec/request/service_brokers_spec.rb']}
        #pp caller[0..idx].map{|x| x.sub(%r{/Users/\w+}, "...")}
        #debugger
        # spec_line = caller.find{|s| s['spec/request/service_brokers_spec.rb'] }
        # warn("QQQ: Jobs::LoggingContextJob.error:\n  ** spec line: #{spec_line},\n  ** job handler: #{job.handler},\n  ** e: <#{e}>\n\n")
        error_presenter = ErrorPresenter.new(e)
        # warn("QQQ: error_presenter: <#{error_presenter}>,\nerror_presenter.to_hash:#{error_presenter.to_hash}\n\n")
        log_error(error_presenter, job)
        save_error(error_presenter, job)
        super(job, e)
      end

      private

      def save_error(error_presenter, job)
        job.cf_api_error = YAML.dump(error_presenter.to_hash)
        deprioritize_job(job)
        job.save
        # warn("QQQ: save_error: reloaded error for job class #{job.class}, id #{job.id}: guid: #{job.guid}\ncf_api_error: <#{job.reload.cf_api_error}>")
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
