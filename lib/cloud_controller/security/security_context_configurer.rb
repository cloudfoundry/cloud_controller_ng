module VCAP::CloudController
  module Security
    class SecurityContextConfigurer
      def initialize(token_decoder)
        @token_decoder = token_decoder
      end

      def configure(header_token)
        VCAP::CloudController::SecurityContext.clear
        token_information = decode_token(header_token)

        user = user_from_token(token_information)

        VCAP::CloudController::SecurityContext.set(user, token_information, header_token)
      rescue VCAP::CloudController::UaaTokenDecoder::BadToken
        VCAP::CloudController::SecurityContext.set(nil, :invalid_token, header_token)
      end

      private
      UUID_REGEX = /\A[\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12}\z/i.freeze

      def decode_token(header_token)
        token_information = @token_decoder.decode_token(header_token)
        return nil if token_information.nil? || token_information.empty?

        if !token_information['user_id'] && token_information['client_id']
          if is_shadowing_user?(token_information['client_id'])
            logger.error("Invalid token client_id: #{token_information['client_id']}")
            raise VCAP::CloudController::UaaTokenDecoder::BadToken
          end

          token_information['user_id'] = token_information['client_id']
        end
        token_information
      end

      def is_user_in_uaadb?(id)
        CloudController::DependencyLocator.instance.uaa_client.usernames_for_ids(Array(id)).present?
      end

      def is_uuid_shaped?(id)
        return true if id =~ UUID_REGEX
      end

      def is_shadowing_user?(client_id)
        is_uuid_shaped?(client_id) && is_user_in_uaadb?(client_id)
      end

      def user_from_token(token)
        user_guid = token && token['user_id']
        return unless user_guid

        User.find(guid: user_guid.to_s) || User.create(guid: user_guid, active: true)
      rescue Sequel::ValidationFailed
        User.find(guid: user_guid.to_s)
      rescue Sequel::UniqueConstraintViolation
        User.find(guid: user_guid.to_s)
      end

      def logger
        @logger ||= Steno.logger('security_context_configurer')
      end
    end
  end
end
