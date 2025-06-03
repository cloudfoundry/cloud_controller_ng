# frozen_string_literal: true

require 'cloud_controller/diego/bbs_environment_builder'

module VCAP::CloudController
  module Diego
    class InvalidWindowsGMSACredentials < CloudController::Errors::ApiError; end
    class WindowsEnvironmentSage
      def self.ponder(app)
        windows_gmsa_credential_env(app)
      end

      def self.windows_gmsa_credential_env(app)
        credential_refs = app.windows_gmsa_credential_refs
        if credential_refs.empty?
          return []
        elsif credential_refs.size > 1
          raise InvalidWindowsGMSACredentials.new_from_details('AppInvalid', 'Having more than one Windows GMSA credential binding is not supported')
        else
          return BbsEnvironmentBuilder.build('WINDOWS_GMSA_CREDENTIAL_REF' => credential_refs.first)
        end

      end
      private_class_method :windows_gmsa_credential_env
    end
  end
end
