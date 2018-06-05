require 'messages/base_message'

module VCAP::CloudController
  class PackageUploadMessage < BaseMessage
    class MissingFilePathError < StandardError; end

    register_allowed_keys [:bits_path, :bits_name, :resources]

    validates_with NoAdditionalKeysValidator

    validates :bits_path, presence: { presence: true, message: 'An application zip file must be uploaded' }
    validate :bits_path_in_tmpdir

    def self.create_from_params(params)
      opts = params.dup.symbolize_keys

      if opts.key?(VCAP::CloudController::Constants::NGINX_UPLOAD_MODULE_DUMMY.to_sym)
        raise MissingFilePathError.new('File field missing path information')
      end

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

    def bits_path_in_tmpdir
      return unless bits_path
      unless FilePathChecker.safe_path?(bits_path, tmpdir)
        errors.add(:bits_path, 'is invalid')
      end
    end

    def tmpdir
      VCAP::CloudController::Config.config.get(:directories, :tmpdir)
    end
  end
end
