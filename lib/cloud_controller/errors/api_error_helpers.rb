module CloudController
  module Errors
    module ApiErrorHelpers
      def api_error!(name, *args)
        raise CloudController::Errors::ApiError.new_from_details(name, *args)
      end

      def v3_api_error!(name, *args)
        raise CloudController::Errors::V3::ApiError.new_from_details(name, *args)
      end
    end
  end
end
