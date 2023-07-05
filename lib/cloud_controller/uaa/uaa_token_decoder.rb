require 'uaa/info'

module VCAP::CloudController
  class UaaTokenDecoder
    class BadToken < StandardError
    end

    attr_reader :config

    def initialize(uaa_config, grace_period_in_seconds: 0, alternate_reference_time: nil)
      @config = uaa_config
      @logger = Steno.logger('cc.uaa_token_decoder')

      raise ArgumentError.new('grace period should be an integer') unless grace_period_in_seconds.is_a? Integer
      raise ArgumentError.new('grace period and alternate reference time cannot be used together') if (grace_period_in_seconds != 0) && !alternate_reference_time.nil?

      @alternate_reference_time = alternate_reference_time
      @grace_period_in_seconds = grace_period_in_seconds
      if grace_period_in_seconds < 0
        @grace_period_in_seconds = 0
        @logger.warn("negative grace period interval '#{grace_period_in_seconds}' is invalid, changed to 0")
      end
    end

    def decode_token(auth_token)
      return unless token_format_valid?(auth_token)

      if symmetric_key
        decode_token_with_symmetric_key(auth_token)
      else
        decode_token_with_asymmetric_key(auth_token)
      end
    rescue CF::UAA::TokenExpired => e
      @logger.warn('Token expired')
      raise BadToken.new(e.message)
    rescue CF::UAA::DecodeError, CF::UAA::AuthError => e
      @logger.warn("Invalid bearer token: #{e.inspect} #{e.backtrace}")
      raise BadToken.new(e.message)
    end

    private

    def token_format_valid?(auth_token)
      auth_token && auth_token.upcase.start_with?('BEARER')
    end

    def decode_token_with_symmetric_key(auth_token)
      last_error = nil

      thekeys = [symmetric_key, symmetric_key2]

      thekeys.each do |key|
        return decode_token_with_key(auth_token, skey: key)
      rescue CF::UAA::InvalidSignature => e
        last_error = e
      end
      raise last_error
    end

    def decode_token_with_asymmetric_key(auth_token)
      tries      = 2
      last_error = nil
      while tries > 0
        tries -= 1
        # If we uncover issues due to attempting to decode with every
        # key, we can revisit: https://www.pivotaltracker.com/story/show/132270761
        asymmetric_key(decode_token_zone_id(auth_token)).value.each do |key|
          return decode_token_with_key(auth_token, pkey: key)
        rescue CF::UAA::InvalidSignature => e
          last_error = e
        end
        # asymmetric_key.refresh - TODO: [UAA ZONES] Enable once keys are cached.
      end
      raise last_error
    end

    def decode_token_with_key(auth_token, options)
      time = Time.now.utc.to_i
      if @alternate_reference_time
        time = @alternate_reference_time
        @logger.info("using alternate reference time of #{Time.at(@alternate_reference_time)} to calculate token expiry instead of current time")
      end

      options         = { audience_ids: config[:resource_id] }.merge(options)
      token           = CF::UAA::TokenCoder.new(options).decode_at_reference_time(auth_token, time - @grace_period_in_seconds)
      expiration_time = token['exp'] || token[:exp]
      if expiration_time && expiration_time < time
        @logger.warn("token currently expired but accepted within grace period of #{@grace_period_in_seconds} seconds")
      end

      raise BadToken.new('Incorrect token') unless access_token?(token)

      if token['iss'] != uaa_issuer(token['zid'])
        # TODO: [UAA ZONES] Clear cached issuer for this zone id.
        raise BadToken.new('Incorrect issuer') # if token['iss'] != uaa_issuer(token['zid']) - TODO: [UAA ZONES] Enable once issuers are cached.
      end

      token
    end

    def decode_token_zone_id(token)
      segments = token.split('.')
      raise CF::UAA::InvalidTokenFormat.new('Not enough or too many segments') if segments.length < 2 || segments.length > 3

      CF::UAA::Util.json_decode64(segments[1], :sym)[:zid]
    end

    def symmetric_key
      config[:symmetric_secret]
    end

    def symmetric_key2
      config[:symmetric_secret2]
    end

    def asymmetric_key(zone_id)
      # TODO: [UAA ZONES] Cache keys per zone id.
      UaaVerificationKeys.new(uaa_client(zone_id).info)
    end

    def uaa_issuer(zone_id)
      # TODO: [UAA ZONES] Cache issuer per zone id.
      with_request_error_handling do
        fetch_uaa_issuer(zone_id)
      end
    end

    def fetch_uaa_issuer(zone_id)
      uaa_client(zone_id).http_get('/.well-known/openid-configuration')['issuer']
    rescue CF::UAA::UAAError
      raise 'Could not retrieve issuer information from UAA'
    end

    def uaa_client(zone_id)
      UaaClient.new(
        uaa_target: config[:internal_url],
        subdomain: UaaZones.get_subdomain(CloudController::DependencyLocator.instance.uaa_zone_lookup_client, zone_id),
        ca_file: config[:ca_file],
      )
    end

    def with_request_error_handling(&blk)
      tries ||= 3
      yield
    rescue
      retry unless (tries -= 1).zero?
      raise
    end

    def access_token?(token)
      token['jti'] && token['jti'][-2..] != '-r'
    end
  end
end
