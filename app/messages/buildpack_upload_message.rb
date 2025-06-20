require 'messages/base_message'

module VCAP::CloudController
  GZIP_MIME = Regexp.new("\x1F\x8B\x08".force_encoding('binary'))
  ZIP_MIME = Regexp.new("PK\x03\x04".force_encoding('binary'))
  CNB_MIME = Regexp.new("\x75\x73\x74\x61\x72\x00\x30\x30".force_encoding('binary'))

  class BuildpackUploadMessage < BaseMessage
    class MissingFilePathError < StandardError; end
    register_allowed_keys %i[bits_path bits_name upload_start_time]

    validates_with NoAdditionalKeysValidator

    validate :nginx_fields
    validate :bits_path_in_tmpdir
    validate :is_archive
    validate :is_not_empty
    validate :missing_file_path

    attr_reader :lifecycle

    def initialize(params, lifecycle)
      @lifecycle = lifecycle
      super(params)
    end

    def self.create_from_params(params, lifecycle)
      BuildpackUploadMessage.new(params.dup.symbolize_keys, lifecycle)
    end

    def nginx_fields
      return if bits_path && bits_name

      errors.add(:base, 'A buildpack zip file must be uploaded as \'bits\'')
    end

    def bits_path=(value)
      value = File.expand_path(value, tmpdir) if value
      @bits_path = value
    end

    private

    def bits_path_in_tmpdir
      return unless bits_path

      return if FilePathChecker.safe_path?(bits_path, tmpdir)

      errors.add(:bits_path, 'is invalid')
    end

    def tmpdir
      VCAP::CloudController::Config.config.get(:directories, :tmpdir)
    end

    def is_archive
      return unless bits_name
      return unless bits_path

      mime_bits = File.read(bits_path, 4)

      if lifecycle == VCAP::CloudController::Lifecycles::BUILDPACK
        return if mime_bits =~ /^#{VCAP::CloudController::ZIP_MIME}/

        errors.add(:base, "#{bits_name} is not a zip file. Buildpacks of lifecycle \"#{lifecycle}\" must be valid zip files.")
      elsif lifecycle == VCAP::CloudController::Lifecycles::CNB
        return if mime_bits =~ /^#{VCAP::CloudController::GZIP_MIME}/

        mime_bits_at_offset = File.read(bits_path, 8, 257)
        return if mime_bits_at_offset =~ /^#{VCAP::CloudController::CNB_MIME}/

        errors.add(:base, "#{bits_name} is not a gzip archive or cnb file. Buildpacks of lifecycle \"#{lifecycle}\" must be valid gzip archives or cnb files.")
      end
    end

    def missing_file_path
      return unless requested?(VCAP::CloudController::Constants::INVALID_NGINX_UPLOAD_PARAM.to_sym)

      errors.add(:base, 'Uploaded bits are not a valid buildpack file')
    end

    def is_not_empty
      return unless bits_path

      errors.add(:base, "#{bits_name} cannot be empty") unless File.stat(bits_path).size > 0
    end
  end
end
