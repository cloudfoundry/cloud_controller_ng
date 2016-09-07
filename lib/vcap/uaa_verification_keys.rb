module VCAP
  class UaaVerificationKeys
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
      @verification_key.present? ? [@verification_key] : fetch_from_uaa
    end

    def fetch_from_uaa
      keys = []
      @info.validation_keys_hash.each do |_, key|
        keys << key['value']
      end
      keys
    end
  end
end
