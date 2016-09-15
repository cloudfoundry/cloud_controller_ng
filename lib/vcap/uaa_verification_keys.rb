module VCAP
  class UaaVerificationKeys
    def initialize(info)
      @info = info
    end

    def value
      if @uaa_keys.nil? || invalid_keys?
        @uaa_keys = update_keys(@uaa_keys)
      end
      @uaa_keys[:keys]
    end

    def refresh
      @uaa_keys = nil
    end

    def update_keys(last_fetched_keys)
      validation_hash = fetch_from_uaa

      if !(validation_hash.present? || last_fetched_keys)
        logger.error('Fetching uaa verification keys failed')
        raise VCAP::CloudController::UaaUnavailable
      end

      if !validation_hash.present? && last_fetched_keys
        last_fetched_keys
      else
        format_keys(validation_hash)
      end
    end

    def format_keys(validation_hash)
      uaa_keys = { keys: [] }

      validation_hash.each do |_, key|
        uaa_keys[:keys] << key['value']
      end

      uaa_keys[:requested_time] = Time.now
      uaa_keys
    end

    def fetch_from_uaa
      validation_hash = {}
      retries         = 3

      while retries > 0 && !validation_hash.present?
        begin
          validation_hash = @info.validation_keys_hash
        rescue => e
          logger.debug("fetch-verification-keys-retry", error: e, remaining_retries: retries)
          retries -= 1
        end
      end
      validation_hash
    end

    private

    def invalid_keys?
      return true unless Time.now - @uaa_keys[:requested_time] < 30
    end

    def logger
      @logger ||= Steno.logger('cc.uaa_verification_keys')
    end
  end
end
