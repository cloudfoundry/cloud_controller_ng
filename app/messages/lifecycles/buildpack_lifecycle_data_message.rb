module VCAP::CloudController
  class BuildpackLifecycleDataMessage < BaseMessage
    ALLOWED_KEYS = [:buildpack, :stack].freeze

    def self.create_from_http_request(body)
      BuildpackLifecycleDataMessage.new((body || {}).symbolize_keys)
    end

    attr_accessor(*ALLOWED_KEYS)
    def allowed_keys
      ALLOWED_KEYS
    end

    validates_with NoAdditionalKeysValidator

    validates :stack,
      string: true,
      allow_nil: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' }

    validates :buildpack,
      string: true,
      allow_nil: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' }
  end
end
