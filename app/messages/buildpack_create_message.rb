require 'messages/metadata_base_message'
require 'messages/validators'
require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class BuildpackCreateMessage < MetadataBaseMessage
    MAX_BUILDPACK_NAME_LENGTH = 250
    MAX_STACK_LENGTH = 250

    register_allowed_keys %i[name stack position enabled locked lifecycle]
    validates_with NoAdditionalKeysValidator

    validates :name,
              string: true,
              presence: true,
              allow_nil: false,
              length: { maximum: MAX_BUILDPACK_NAME_LENGTH },
              format: /\A[-\w]+\z/

    validates :stack,
              string: true,
              allow_nil: true,
              length: { maximum: MAX_STACK_LENGTH }

    validates :position,
              allow_nil: true,
              numericality: { greater_than_or_equal_to: 1, only_integer: true }

    validates :enabled,
              allow_nil: true,
              boolean: true

    validates :locked,
              allow_nil: true,
              boolean: true

    validates :lifecycle,
              string: true,
              allow_nil: true,
              inclusion: { in: [VCAP::CloudController::Lifecycles::BUILDPACK, VCAP::CloudController::Lifecycles::CNB], message: 'must be either "buildpack" or "cnb"' }
  end
end
