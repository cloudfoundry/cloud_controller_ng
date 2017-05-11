require 'actions/package_update'
require 'messages/packages/internal_package_update_message'

module VCAP::CloudController
  module Internal
    class PackagesController < RestController::BaseController
      allow_unauthenticated_access

      patch '/internal/v4/packages/:guid', :update
      def update(guid)
        payload = MultiJson.load(body)
        message = ::VCAP::CloudController::InternalPackageUpdateMessage.create_from_http_request(payload)
        unprocessable!(message.errors.full_messages) unless message.valid?

        package = ::VCAP::CloudController::PackageModel.find(guid: guid)
        package_not_found! unless package

        PackageUpdate.new.update(package, message)

        HTTP::NO_CONTENT
      rescue PackageUpdate::InvalidPackage => e
        unprocessable!(e.message)
      rescue MultiJson::ParseError => e
        raise CloudController::Errors::ApiError.new_from_details('MessageParseError', e.message)
      end

      private

      def unprocessable!(message)
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', message)
      end

      def package_not_found!
        raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', 'Package not found')
      end
    end
  end
end
