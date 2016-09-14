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

      raise VCAP::CloudController::UaaUnavailable if !(validation_hash.present? || last_fetched_keys)

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
      retries = 3
      validation_hash = {}

      while retries > 0 && !validation_hash.present?
        validation_hash = @info.validation_keys_hash
        retries -= 1
      end

      validation_hash
    end

    private

    def invalid_keys?
      return true unless Time.now - @uaa_keys[:requested_time] < 30
    end
  end
end
