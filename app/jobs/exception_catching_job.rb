module VCAP::CloudController
  module Jobs
    class ExceptionCatchingJob < Struct.new(:handler)
      def perform
        handler.perform
      end

      def error(job, e)
        error_hash = ErrorPresenter.new(e).sanitized_hash
        job.cf_api_error = YAML.dump(error_hash)
        job.save
      end
    end
  end
end