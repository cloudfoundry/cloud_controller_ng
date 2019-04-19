require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class BuildpackUpdateMessage < MetadataBaseMessage
    MAX_BUILDPACK_NAME_LENGTH = 250
    MAX_STACK_LENGTH = 250

    register_allowed_keys [:name, :stack, :position, :enabled, :locked]
    validates_with NoAdditionalKeysValidator

    def self.position_requested?
      @position_requested ||= proc { |a| a.requested?(:position) }
    end

    def self.locked_requested?
      @locked_requested ||= proc { |a| a.requested?(:locked) }
    end

    def self.enabled_requested?
      @enabled_requested ||= proc { |a| a.requested?(:enabled) }
    end

    validates :name,
      string: true,
      length: { maximum: MAX_BUILDPACK_NAME_LENGTH },
      format: /\A[-\w]+\z/,
      allow_nil: true

    validates :stack,
      string: true,
      length: { maximum: MAX_STACK_LENGTH },
      allow_nil: true

    validates :position,
      numericality: { greater_than_or_equal_to: 1, only_integer: true },
      if: position_requested?

    validates :enabled,
      boolean: true,
      if: enabled_requested?

    validates :locked,
      boolean: true,
      if: locked_requested?
  end
end
