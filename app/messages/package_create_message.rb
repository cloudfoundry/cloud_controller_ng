require 'messages/metadata_base_message'
require 'messages/validators/bits_data_validator'
require 'messages/validators/docker_data_validator'

module VCAP::CloudController
  class PackageCreateMessage < MetadataBaseMessage
    register_allowed_keys [:relationships, :type, :data]

    validates_with NoAdditionalKeysValidator,
      DockerDataValidator,
      BitsDataValidator,
      RelationshipValidator

    validates :type, inclusion: { in: %w(bits docker), message: 'must be one of \'bits, docker\'' }

    delegate :app_guid, to: :relationships_message

    def bits_type?
      type == 'bits'
    end

    def docker_type?
      type == 'docker'
    end

    def docker_data
      OpenStruct.new(data) if docker_type?
    end

    def relationships_message
      @relationships_message ||= Relationships.new(relationships.deep_symbolize_keys)
    end

    def audit_hash
      result = super

      if result['data']
        result['data']['password'] = VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL
      end

      result
    end

    class Relationships < BaseMessage
      register_allowed_keys [:app]

      validates_with NoAdditionalKeysValidator

      validates :app, presence: true, allow_nil: false, to_one_relationship: true

      def app_guid
        HashUtils.dig(app, :data, :guid)
      end
    end
  end
end
