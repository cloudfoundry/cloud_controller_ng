module VCAP::CloudController
  class DockerLifecycleDataMessage < BaseMessage
    register_allowed_keys []

    validates_with NoAdditionalKeysValidator

    def self.create_from_http_request(body)
      DockerLifecycleDataMessage.new((body || {}).deep_symbolize_keys)
    end
  end
end
