require 'messages/base_message'

module VCAP::CloudController
  class InternalPackageUpdateMessage < BaseMessage
    register_allowed_keys %i[state checksums error]

    validates_with NoAdditionalKeysValidator

    validate :requested_state
    validates :error, length: { in: 1..500, message: 'must be between 1 and 500 characters', allow_nil: true }
    validate :checksums_data, if: :requested_checksum?

    def sha1
      sha1_hash = checksums&.find { |checksum| checksum[:type] == Checksum::SHA1 }
      HashUtils.dig(sha1_hash, :value)
    end

    def sha256
      sha256_hash = checksums&.find { |checksum| checksum[:type] == Checksum::SHA256 }
      HashUtils.dig(sha256_hash, :value)
    end

    private

    def requested_state
      return if [PackageModel::PENDING_STATE, PackageModel::READY_STATE, PackageModel::FAILED_STATE].include?(state)

      errors.add(:state, 'must be one of PROCESSING_UPLOAD, READY, FAILED')
    end

    def requested_ready?
      state == PackageModel::READY_STATE
    end

    def requested_checksum?
      checksums.present?
    end

    def checksums_data
      errors.add(:checksums, message: 'has invalid structure') unless checksums.is_a?(Array) && checksums.each { |checksum| checksum.is_a?(Hash) }

      if errors[:checksums].empty?
        checksum_messages = checksums.map { |checksum| Checksum.new(checksum.deep_symbolize_keys) }
        invalid_errors = checksum_messages.select(&:invalid?).map { |checksum| checksum.errors.full_messages }.flatten
        invalid_errors.each do |message|
          errors.add(:checksums, message:)
        end
      end

      return if checksums.length == 2 && sha1 && sha256

      errors.add(:checksums, 'both sha1 and sha256 checksums must be provided')
    end
  end

  class Checksum < ::VCAP::CloudController::BaseMessage
    register_allowed_keys %i[type value]
    SHA1         = 'sha1'.freeze
    SHA256       = 'sha256'.freeze

    def allowed_keys
      ALLOWED_KEYS
    end

    validates_with NoAdditionalKeysValidator

    validates :type, inclusion: { in: [SHA1, SHA256], message: 'must be one of sha1, sha256' }
    validates :value, length: { in: 1..500, message: 'must be between 1 and 500 characters' }
  end
end
