require 'messages/base_message'

module VCAP::CloudController
  class PackageUploadMessage < BaseMessage
    class MissingFilePathError < StandardError; end

    register_allowed_keys [:bits_path, :bits_name, :upload_start_time, :resources]

    validates_with NoAdditionalKeysValidator

    validate :bits_path_or_resources_presence
    validate :bits_path_in_tmpdir
    validate :missing_file_path

    def self.create_from_params(params)
      opts = params.dup.symbolize_keys

      if opts[:bits].present?
        opts[:bits_path] = opts[:bits].tempfile.path
        opts.delete(:bits)
      end

      PackageUploadMessage.new(opts)
    end

    def bits_path=(value)
      value = File.expand_path(value, tmpdir) if value
      @bits_path = value
    end

    private

    def bits_path_or_resources_presence
      if bits_path.blank? && resources.blank?
        errors.add(:base, 'Upload must include either resources or bits')
      end
    end

    def bits_path_in_tmpdir
      return unless bits_path

      unless FilePathChecker.safe_path?(bits_path, tmpdir)
        errors.add(:bits_path, 'is invalid')
      end
    end

    def missing_file_path
      return unless requested?(VCAP::CloudController::Constants::INVALID_NGINX_UPLOAD_PARAM.to_sym)

      errors.add(:base, 'File field missing path information')
    end

    def tmpdir
      VCAP::CloudController::Config.config.get(:directories, :tmpdir)
    end
  end
end
