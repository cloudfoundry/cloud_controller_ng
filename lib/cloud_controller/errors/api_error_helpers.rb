module CloudController
  module Errors
    module ApiErrorHelpers
      def api_error!(name, *)
        raise CloudController::Errors::ApiError.new_from_details(name, *)
      end

      def v3_api_error!(name, *)
        raise CloudController::Errors::V3::ApiError.new_from_details(name, *)
      end
    end
  end
end
