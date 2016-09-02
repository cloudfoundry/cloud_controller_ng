module VCAP
  class UaaVerificationKeys
    def initialize(info)
      @info = info
    end

    def value
      @value ||= fetch_from_uaa
    end

    def refresh
      @value = nil
    end

    private

    def fetch_from_uaa
      keys = []
      @info.validation_keys_hash.each do |_, key|
        keys << key['value']
      end
      keys
    end
  end
end
