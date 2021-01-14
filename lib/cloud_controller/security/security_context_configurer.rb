module VCAP::CloudController
  module Security
    class SecurityContextConfigurer
      def initialize(token_decoder)
        @token_decoder = token_decoder
      end

      def configure(header_token)
        VCAP::CloudController::SecurityContext.clear
        decoded_token = decode_token(header_token)

        user = user_from_token(decoded_token)
        set_is_oauth_client(user, decoded_token)
        VCAP::CloudController::SecurityContext.set(user, decoded_token, header_token)
      rescue VCAP::CloudController::UaaTokenDecoder::BadToken
        VCAP::CloudController::SecurityContext.set(nil, :invalid_token, header_token)
      end

      private

      UUID_REGEX = /\A[\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12}\z/i.freeze

      def decode_token(header_token)
        token_information = @token_decoder.decode_token(header_token)
        return nil if token_information.nil? || token_information.empty?

        token_information
      end

      def is_user_in_uaadb?(id)
        CloudController::DependencyLocator.instance.uaa_client.usernames_for_ids(Array(id)).present?
      end

      def is_uuid_shaped?(id)
        id =~ UUID_REGEX
      end

      def client_is_shadowing_user?(client_id)
        client_id && is_uuid_shaped?(client_id) && is_user_in_uaadb?(client_id)
      end

      def set_is_oauth_client(user, token)
        if user && user.is_oauth_client.nil?
          user.update(is_oauth_client: is_oauth_client?(token))
        end
      end

      def user_from_token(token)
        guid = token && (token['user_id'] || token['client_id'])
        return unless guid

        validate_unique_user(token, guid)

        User.find(guid: guid.to_s) || User.create(guid: guid, active: true, is_oauth_client: is_oauth_client?(token))
      rescue Sequel::ValidationFailed,
             Sequel::UniqueConstraintViolation
        User.find(guid: guid.to_s)
      end

      def validate_unique_user(token, guid)
        if is_oauth_client?(token)
          if User.find(guid: guid.to_s, is_oauth_client: false) || client_is_shadowing_user?(token['client_id'])
            logger.error("Invalid token client_id: #{token['client_id']}")
            raise VCAP::CloudController::UaaTokenDecoder::BadToken
          end
        elsif User.find(guid: guid.to_s, is_oauth_client: true)
          logger.error("Invalid token user_id: #{token['user_id']}")
          raise VCAP::CloudController::UaaTokenDecoder::BadToken
        end
      end

      def is_oauth_client?(token)
        !token.key?('user_id') && token.key?('client_id')
      end

      def logger
        @logger ||= Steno.logger('security_context_configurer')
      end
    end
  end
end
