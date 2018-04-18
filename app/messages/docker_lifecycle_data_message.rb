module VCAP::CloudController
  class DockerLifecycleDataMessage < BaseMessage
    register_allowed_keys []

    validates_with NoAdditionalKeysValidator
  end
end
