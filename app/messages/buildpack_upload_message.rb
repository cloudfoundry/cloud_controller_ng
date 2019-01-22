require 'messages/base_message'

module VCAP::CloudController
  class BuildpackUploadMessage < BaseMessage
    class MissingFilePathError < StandardError; end

    register_allowed_keys [:bits_path, :bits_name]

    validates_with NoAdditionalKeysValidator

    validate :nginx_fields
    validate :bits_path_in_tmpdir
    validate :is_zip
    validate :is_not_empty

    def self.create_from_params(params)
      opts = params.dup.symbolize_keys

      if opts.key?(VCAP::CloudController::Constants::INVALID_NGINX_UPLOAD_PARAM.to_sym)
        raise MissingFilePathError.new('Uploaded bits were not a valid buildpack file')
      end

      BuildpackUploadMessage.new(opts)
    end

    def nginx_fields
      unless bits_path && bits_name
        errors.add(:base, 'A buildpack zip file must be uploaded as \'bits\'')
      end
    end

    def bits_path=(value)
      value = File.expand_path(value, tmpdir) if value
      @bits_path = value
    end

    private

    def bits_path_in_tmpdir
      return unless bits_path

      unless FilePathChecker.safe_path?(bits_path, tmpdir)
        errors.add(:bits_path, 'is invalid')
      end
    end

    def tmpdir
      VCAP::CloudController::Config.config.get(:directories, :tmpdir)
    end

    def is_zip
      return unless bits_name

      errors.add(:base, "#{bits_name} is not a zip") unless File.extname(bits_name) == '.zip'
    end

    def is_not_empty
      return unless bits_path

      errors.add(:base, "#{bits_name} may not be empty") unless File.stat(bits_path).size > 0
    end
  end
end
