require 'messages/base_message'

module VCAP::CloudController
  class DropletCreateMessage < BaseMessage
    attr_accessor :memory_limit, :disk_limit, :stack, :buildpack, :environment_variables

    def allowed_keys
      [:memory_limit, :disk_limit, :stack, :buildpack, :environment_variables]
    end

    validates_with NoAdditionalKeysValidator, EnvironmentVariablesValidator

    validates :memory_limit, numericality: { only_integer: true }, allow_nil: true

    validates :disk_limit, numericality: { only_integer: true }, allow_nil: true

    validates :stack,
      string: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
      if:     proc { |a| a.requested?(:stack) }

    validates :buildpack, string: true, allow_nil: true

    def self.create_from_http_request(body)
      DropletCreateMessage.new(body.symbolize_keys)
    end
  end
end
