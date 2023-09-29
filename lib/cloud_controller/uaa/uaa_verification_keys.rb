module VCAP::CloudController
  class UaaVerificationKeys
    def initialize(info)
      @info = info
    end

    def value
      @uaa_keys = update_keys(@uaa_keys) if @uaa_keys.nil? || invalid_keys?
      @uaa_keys[:keys]
    end

    def refresh
      @uaa_keys = nil
    end

    private

    def update_keys(last_fetched_keys)
      validation_hash = fetch_from_uaa

      unless validation_hash.present? || last_fetched_keys
        logger.error('Fetching uaa verification keys failed')
        raise VCAP::CloudController::UaaUnavailable
      end

      if validation_hash.blank? && last_fetched_keys
        last_fetched_keys
      else
        format_keys(validation_hash)
      end
    end

    def format_keys(validation_hash)
      uaa_keys = { keys: [] }

      validation_hash.each_value do |key|
        uaa_keys[:keys] << key['value']
      end

      uaa_keys[:requested_time] = Time.now
      uaa_keys
    end

    # Gets validation keys from the UAA server.  Retries 3 times.  Returns a validation hash.  Retries if hash is empty and retries remaining.
    def fetch_from_uaa
      validation_hash = {}
      retries         = 3

      while retries > 0 && validation_hash.blank?
        begin
          validation_hash = @info.validation_keys_hash
        rescue StandardError => e
          logger.error('fetch-verification-keys-retry', error: e.message, remaining_retries: retries - 1)
        end
        retries -= 1
      end
      validation_hash
    end

    def invalid_keys?
      true unless Time.now - @uaa_keys[:requested_time] < 30
    end

    def logger
      @logger ||= Steno.logger('cc.uaa_verification_keys')
    end
  end
end
