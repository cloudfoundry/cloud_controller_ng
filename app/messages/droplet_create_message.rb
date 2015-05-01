require 'messages/base_message'

module VCAP::CloudController
  class DropletCreateMessage < BaseMessage
    attr_accessor :memory_limit, :disk_limit, :stack, :buildpack_git_url, :buildpack_guid

    def allowed_keys
      [:memory_limit, :disk_limit, :stack, :buildpack_git_url, :buildpack_guid]
    end

    validates_with NoAdditionalKeysValidator

    validates :memory_limit, numericality: { only_integer: true }, allow_nil: true

    validates :disk_limit, numericality: { only_integer: true }, allow_nil: true

    validates :stack,
      string: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
      if:     proc { |a| a.requested?(:stack) }

    validates :buildpack_git_url, uri: true, allow_nil: true
    validates :buildpack_git_url,
      absence: { absence: true, message: 'Only one of buildpack_git_url or buildpack_guid may be provided' },
      if: 'requested?(:buildpack_guid)'

    validates :buildpack_guid, guid: true, allow_nil: true

    def self.create_from_http_request(body)
      DropletCreateMessage.new(body.symbolize_keys)
    end
  end
end
