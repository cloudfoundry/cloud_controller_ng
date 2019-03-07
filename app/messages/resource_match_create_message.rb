require 'messages/base_message'
require 'messages/validators'

module VCAP::CloudController
  class ResourceMatchCreateMessage < BaseMessage
    register_allowed_keys [:resources]

    validates :resources, array: true, length: {
      maximum: 5000,
      too_long: 'is too many (maximum is %{count} resources)',
      minimum: 1,
      too_short: 'must have at least %{count} resource'
    }
    validate :each_resource

    def self.from_v2_fingerprints(body)
      v3_body = {
        'resources' => MultiJson.load(body.string).map do |r|
          {
            'size_in_bytes' => r['size'],
            'checksum' => { 'value' => r['sha1'] }
          }
        end
      }
      new(v3_body)
    end

    def v2_fingerprints_body
      v2_fingerprints = resources.map do |resource|
        {
          sha1: resource[:checksum][:value],
          size: resource[:size_in_bytes]
        }
      end

      StringIO.new(v2_fingerprints.to_json)
    end

    private

    def each_resource
      if resources.is_a?(Array)
        resources.each do |r|
          checksum_validator(r[:checksum])
          size_validator(r[:size_in_bytes])
        end
      end
    end

    def checksum_validator(checksum)
      unless checksum.is_a?(Hash)
        errors.add(:resources, 'At least one checksum is not an object')
        return
      end

      unless checksum[:value].is_a?(String)
        errors.add(:resources, 'At least one checksum value is not a string')
        return
      end

      unless valid_sha1?(checksum[:value])
        errors.add(:resources, 'At least one checksum value is not SHA-1 format')
        return
      end
    end

    def size_validator(size)
      unless size.is_a?(Integer)
        errors.add(:resources, 'All sizes must be non-negative integers')
        return
      end

      unless size >= 0
        errors.add(:resources, 'All sizes must be non-negative integers') if size < 0
        return
      end
    end

    def valid_sha1?(value)
      value.length == VCAP::CloudController::ResourcePool::VALID_SHA_LENGTH
    end
  end
end
