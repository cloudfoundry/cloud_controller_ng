require 'messages/base_message'

module VCAP::CloudController
  class ManifestBuildpackMessage < BaseMessage
    register_allowed_keys [:buildpack]

    validates_with NoAdditionalKeysValidator

    validates :buildpack,
      string:    true,
      allow_nil: true,
      length:    { in: 1..4096, message: 'must be between 1 and 4096 characters' },
      if: proc { |record| record.requested?(:buildpack) }
  end
end
