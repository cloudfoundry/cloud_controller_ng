require 'messages/base_message'
require 'messages/validators'

module VCAP::CloudController
  class BuildpackUpdateMessage < BaseMessage
    register_allowed_keys [:name, :stack, :position, :enabled, :locked]
    validates_with NoAdditionalKeysValidator

    validates :name,
      string: true,
      allow_nil: true,
      length: { maximum: 250 },
      format: /\A[-\w]+\z/

    validates :stack,
      string: true,
      allow_nil: true,
      length: { maximum: 250 }

    validates :position,
      allow_nil: true,
      numericality: { greater_than_or_equal_to: 1, only_integer: true }

    validates :enabled,
      allow_nil: true,
      inclusion: { in: [true, false], message: 'must be a boolean' }

    validates :locked,
      allow_nil: true,
      inclusion: { in: [true, false], message: 'must be a boolean' }
  end
end
