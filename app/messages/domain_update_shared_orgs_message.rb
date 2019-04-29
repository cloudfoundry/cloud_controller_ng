require 'messages/metadata_base_message'

module VCAP::CloudController
  class DomainUpdateSharedOrgsMessage < MetadataBaseMessage
    register_allowed_keys [
      :data,
      :guid
    ]

    validates_with NoAdditionalKeysValidator
    validate :validate_data

    def validate_data
      errors.add(:base, 'Data must have the structure "data": [{"guid": shared_org_guid_1}, {"guid": shared_org_guid_2}]') unless data_is_valid?
    end

    def data_is_valid?
      data && data.is_a?(Array) && objects_are_guid_hashes?
    end

    def objects_are_guid_hashes?
      data.all? do |d|
        d.is_a?(Hash) && d[:guid] && d[:guid].is_a?(String) && (1..200).cover?(d[:guid].size)
      end
    end

    def shared_organizations_guids
      data.map { |hsh| hsh[:guid] }
    end
  end
end
