# frozen_string_literal: true

require 'cloud_controller/diego/bbs_environment_builder'

module VCAP::CloudController
  module Diego
    class InvalidWindowsGMSACredentials < StandardError; end
    class WindowsEnvironmentSage
      def self.ponder(app)
        windows_gmsa_credential_env(app)
      end

      def self.windows_gmsa_credential_env(app)
        credential_refs = app.windows_gmsa_credential_refs
        return [] if credential_refs.empty?
        raise InvalidWindowsGMSACredentials if credential_refs.size > 1

        BbsEnvironmentBuilder.build('WINDOWS_GMSA_CREDENTIAL_REF' => credential_refs.first)
      end
      private_class_method :windows_gmsa_credential_env
    end
  end
end
