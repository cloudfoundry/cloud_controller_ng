require "uaa/misc"

module VCAP
  module UaaUtil
    def decode_token(auth_token)
      return unless token_format_valid?(auth_token)

      if symmetric_key
        decode_token_with_symmetric_key(auth_token)
      else
        decode_token_with_asymmetric_key(auth_token)
      end
    end

    private

    def token_format_valid?(auth_token)
      auth_token && auth_token.upcase.start_with?("BEARER")
    end

    def decode_token_with_symmetric_key(auth_token)
      decode_token_with_key(auth_token, :skey => symmetric_key)
    end

    def decode_token_with_asymmetric_key(auth_token)
      tries = 2
      begin
        tries -= 1
        decode_token_with_key(auth_token, :pkey => asymmetric_key.value)
      rescue CF::UAA::InvalidSignature => e
        asymmetric_key.refresh
        tries > 0 ? retry : raise
      end
    end

    def decode_token_with_key(auth_token, options)
      options = {:audience_ids => config[:uaa][:resource_id]}.merge(options)
      CF::UAA::TokenCoder.new(options).decode(auth_token)
    end

    def symmetric_key
      config[:uaa][:symmetric_secret]
    end

    def asymmetric_key
      @asymmetric_key ||= UaaVerificationKey.new(config[:uaa])
    end

    class UaaVerificationKey
      def initialize(config)
        @config = config
      end

      def value
        @value ||= fetch
      end

      def refresh
        @value = nil
      end

      private

      def fetch
        @config[:verification_key] || CF::UAA::Misc.validation_key(@config[:url])["value"]
      end
    end
  end
end
