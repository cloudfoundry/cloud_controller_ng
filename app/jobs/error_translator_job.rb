module VCAP::CloudController
  module Jobs
    class ErrorTranslatorJob < VCAP::CloudController::Jobs::WrappingJob
      def error(job, err)
        err = translate_error(err)
        super(job, err)
      end

      def translate_error(err)
        err
      end
    end
  end
end
