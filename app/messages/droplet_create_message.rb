require 'messages/base_message'
require 'messages/validators'

module VCAP::CloudController
  class DropletCreateMessage < BaseMessage
    ALLOWED_KEYS = [:memory_limit, :disk_limit, :stack, :buildpack, :environment_variables]

    attr_accessor(*ALLOWED_KEYS)

    validates :memory_limit, numericality: { only_integer: true }, allow_nil: true
    validates :disk_limit, numericality: { only_integer: true }, allow_nil: true
    validates :environment_variables, environment_variables: true, allow_nil: true

    validates :stack,
      string: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
      if:     proc { |a| a.requested?(:stack) }

    validates :buildpack, string: true, allow_nil: true

    def self.create_from_http_request(body)
      DropletCreateMessage.new(body.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
