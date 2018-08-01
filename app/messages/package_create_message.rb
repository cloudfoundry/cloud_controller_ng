require 'messages/base_message'
require 'messages/package_create/bits_data_validator'
require 'messages/package_create/docker_data_validator'

module VCAP::CloudController
  class PackageCreateMessage < BaseMessage
    ALLOWED_KEYS = [:app_guid, :type, :data].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator, DockerDataValidator, BitsDataValidator

    validates :type, inclusion: { in: %w(bits docker), message: 'must be one of \'bits, docker\'' }
    validates :app_guid, guid: true

    def self.create_from_http_request(app_guid, body)
      PackageCreateMessage.new(body.deep_symbolize_keys.merge({ app_guid: app_guid }))
    end

    def bits_type?
      type == 'bits'
    end

    def docker_type?
      type == 'docker'
    end

    def docker_data
      OpenStruct.new(data) if docker_type?
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
