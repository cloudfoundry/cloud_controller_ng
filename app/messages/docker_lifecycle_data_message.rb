module VCAP::CloudController
  class DockerLifecycleDataMessage < BaseMessage
    ALLOWED_KEYS = [].freeze

    attr_accessor(*ALLOWED_KEYS)
    def allowed_keys
      ALLOWED_KEYS
    end
    validates_with NoAdditionalKeysValidator
  end
end
