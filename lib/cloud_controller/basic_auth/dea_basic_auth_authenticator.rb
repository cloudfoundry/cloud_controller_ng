module CloudController
  module BasicAuth
    class DeaBasicAuthAuthenticator
      def self.valid?(rack_env, credentials)
        auth = Rack::Auth::Basic::Request.new(rack_env)
        decoded_credentials = credentials.map { |encoded_cred| URI.decode(encoded_cred) }
        auth.provided? && auth.basic? && auth.credentials == decoded_credentials
      end
    end
  end
end
