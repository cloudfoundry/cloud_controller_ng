require 'messages/base_message'
require 'messages/validators'
require 'messages/v2_v3_resource_translator'

module VCAP::CloudController
  class ResourceMatchCreateMessage < BaseMessage
    register_allowed_keys [:resources]

    validates :resources, array: true, length: {
      maximum: 5000,
      too_long: 'array can have at most %<count>i resources',
      minimum: 1,
      too_short: 'must have at least %<count>i resource'
    }
    validate :each_resource

    def v2_fingerprints_body
      translator = V2V3ResourceTranslator.new(resources)

      StringIO.new(translator.v2_fingerprints_body.to_json)
    end

    private

    PERMISSIONS_REGEX = /^[0-7]{3,4}$/

    def each_resource
      if resources.is_a?(Array)
        resources.each do |r|
          checksum_validator(r[:checksum])
          size_validator(r[:size_in_bytes])
          mode_validator(r[:mode])
        end
      end
    end

    RESOURCE_ERROR_PREAMBLE = 'array contains at least one resource with'.freeze

    def checksum_validator(checksum)
      unless checksum.is_a?(Hash)
        errors.add(:resources, "#{RESOURCE_ERROR_PREAMBLE} a non-object checksum") unless errors.added?(
          :resources, "#{RESOURCE_ERROR_PREAMBLE} a non-object checksum"
        )
        return
      end

      unless checksum[:value].is_a?(String)
        errors.add(:resources, "#{RESOURCE_ERROR_PREAMBLE} a non-string checksum value") unless errors.added?(
          :resources, "#{RESOURCE_ERROR_PREAMBLE} a non-string checksum value"
        )
        return
      end

      unless valid_sha1?(checksum[:value])
        errors.add(:resources, "#{RESOURCE_ERROR_PREAMBLE} a non-SHA1 checksum value") unless errors.added?(
          :resources, "#{RESOURCE_ERROR_PREAMBLE} a non-SHA1 checksum value"
        )
      end
    end

    def size_validator(size)
      unless size.is_a?(Integer)
        errors.add(:resources, "#{RESOURCE_ERROR_PREAMBLE} a non-integer size_in_bytes") unless errors.added?(
          :resources, "#{RESOURCE_ERROR_PREAMBLE} a non-integer size_in_bytes"
        )
        return
      end

      unless size >= 0
        errors.add(:resources, "#{RESOURCE_ERROR_PREAMBLE} a negative size_in_bytes") unless errors.added?(
          :resources, "#{RESOURCE_ERROR_PREAMBLE} a negative size_in_bytes"
        )
      end
    end

    def mode_validator(mode)
      return if mode.nil?

      unless mode.is_a?(String)
        errors.add(:resources, "#{RESOURCE_ERROR_PREAMBLE} a non-string mode") unless errors.added?(
          :resources, "#{RESOURCE_ERROR_PREAMBLE} a non-string mode"
        )
        return
      end

      unless PERMISSIONS_REGEX.match?(mode)
        errors.add(:resources, "#{RESOURCE_ERROR_PREAMBLE} an incorrect mode") unless errors.added?(
          :resources, "#{RESOURCE_ERROR_PREAMBLE} an incorrect mode"
        )
      end
    end

    def valid_sha1?(value)
      value.length == VCAP::CloudController::ResourcePool::VALID_SHA_LENGTH
    end
  end
end
