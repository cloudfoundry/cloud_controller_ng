require 'messages/base_message'
require 'messages/validators'

module VCAP::CloudController
  class BuildpackUpdateMessage < BaseMessage
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
      length: { maximum: 250 },
      format: /\A[-\w]+\z/,
      allow_nil: true

    validates :stack,
      string: true,
      length: { maximum: 250 },
      allow_nil: true

    validates :position,
      numericality: { greater_than_or_equal_to: 1, only_integer: true },
      if: position_requested?

    validates :enabled,
      inclusion: { in: [true, false], message: 'must be a boolean' },
      if: enabled_requested?

    validates :locked,
      inclusion: { in: [true, false], message: 'must be a boolean' },
      if: locked_requested?
  end
end
