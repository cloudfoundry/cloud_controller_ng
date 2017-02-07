require 'messages/base_message'
require 'messages/packages/package_create/bits_data_validator'
require 'messages/packages/package_create/docker_data_validator'

module VCAP::CloudController
  class PackageCreateMessage < BaseMessage
    ALLOWED_KEYS = [:relationships, :type, :data].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator,
      DockerDataValidator,
      BitsDataValidator,
      RelationshipValidator

    validates :type, inclusion: { in: %w(bits docker), message: 'must be one of \'bits, docker\'' }

    def self.create_from_http_request(body)
      PackageCreateMessage.new(body.deep_symbolize_keys)
    end

    def bits_type?
      type == 'bits'
    end

    def app_guid
      relationships.try(:[], :app).try(:[], :guid)
    end

    def docker_type?
      type == 'docker'
    end

    def docker_data
      OpenStruct.new(data) if docker_type?
    end

    class Relationships < BaseMessage
      attr_accessor :app

      def allowed_keys
        [:app]
      end

      validates_with NoAdditionalKeysValidator

      validates :app, presence: true, allow_nil: false, to_one_relationship: true
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
