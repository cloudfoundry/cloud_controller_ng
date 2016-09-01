module VCAP
  class UaaVerificationKeys
    def initialize(info)
      @info = info
      @refresh_time = Time.now
    end

    def value
      if Time.now - @refresh_time > 30
        refresh
      end
      @value ||= fetch_from_uaa
    end

    def refresh
      @value = nil
      @refresh_time = Time.now
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
