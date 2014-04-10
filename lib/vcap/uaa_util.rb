require "uaa/info"

module VCAP
  class UaaTokenDecoder
    attr_reader :config

    def initialize(config)
      @config = config
    end

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
      options = {:audience_ids => config[:resource_id]}.merge(options)
      CF::UAA::TokenCoder.new(options).decode(auth_token)
    end

    def symmetric_key
      config[:symmetric_secret]
    end

    def asymmetric_key
      info = CF::UAA::Info.new(config[:url])
      @asymmetric_key ||= UaaVerificationKey.new(config[:verification_key], info)
    end
  end

  class UaaVerificationKey
    def initialize(verification_key, info)
      @verification_key = verification_key
      @info = info
    end

    def value
      @value ||= fetch
    end

    def refresh
      @value = nil
    end

    private

    def fetch
      @verification_key || @info.validation_key["value"]
    end
  end
end
