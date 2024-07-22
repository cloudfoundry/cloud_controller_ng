require 'messages/base_message'

module VCAP::CloudController
  GZIP_MIME = Regexp.new("\x1F\x8B\x08".force_encoding('binary'))
  ZIP_MIME = Regexp.new("PK\x03\x04".force_encoding('binary'))

  class BuildpackUploadMessage < BaseMessage
    class MissingFilePathError < StandardError; end
    register_allowed_keys %i[bits_path bits_name upload_start_time]

    validates_with NoAdditionalKeysValidator

    validate :nginx_fields
    validate :bits_path_in_tmpdir
    validate :is_archive
    validate :is_not_empty
    validate :missing_file_path

    def self.create_from_params(params)
      BuildpackUploadMessage.new(params.dup.symbolize_keys)
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

      return if mime_bits =~ /^#{VCAP::CloudController::GZIP_MIME}/ || mime_bits =~ /^#{VCAP::CloudController::ZIP_MIME}/

      errors.add(:base, "#{bits_name} is not a zip or gzip archive")
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
