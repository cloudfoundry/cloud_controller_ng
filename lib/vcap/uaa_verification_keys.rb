module VCAP
  class UaaVerificationKeys
    def initialize(info)
      @info = info
    end

    def value
      if @uaa_keys.nil? || !valid_keys?
        @uaa_keys = fetch_from_uaa
      end
      @uaa_keys[:keys]
    end

    def refresh
      @uaa_keys = nil
    end

    private

    def valid_keys?
      return true unless Time.now - @uaa_keys[:requested_time] > 30
    end

    def fetch_from_uaa
      uaa_keys = { keys: [] }

      @info.validation_keys_hash.each do |_, key|
        uaa_keys[:keys] << key['value']
      end

      uaa_keys[:requested_time] = Time.now
      uaa_keys
    end
  end
end
