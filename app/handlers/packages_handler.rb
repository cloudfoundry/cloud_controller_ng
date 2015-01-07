module VCAP::CloudController
  class PackageCreateMessage
    attr_reader :app_guid, :type, :filepath

    def initialize(app_guid, opts)
      @app_guid = app_guid
      @type     = opts['type']
      @filepath = opts['bits_path']
      @filename = opts['bits_name']
    end

    def validate
      errors = []
      errors << validate_type_field
      errors << validate_file if @type == 'bits'
      errs = errors.compact
      return errs.length == 0, errs
    end

    private

    def validate_type_field
      return 'The type field is required' if @type.nil?
      valid_type_fields = %w(bits docker)

      if !valid_type_fields.include?(@type)
        return "The type field needs to be one of '#{valid_type_fields.join(", ")}'"
      end
      nil
    end

    def validate_file
      return 'Must upload an application zip file' if @filepath.nil?
      nil
    end
  end

  class PackagesHandler
    class Unauthorized < StandardError; end
    class InvalidPackage < StandardError; end

    PACKAGE_STATES = %w[PENDING READY FAILED].map(&:freeze).freeze

    def initialize(config)
      @config = config
    end

    def create(message, access_context)
      package          = PackageModel.new
      package.app_guid = message.app_guid
      package.type     = message.type

      raise Unauthorized if access_context.cannot?(:create,  package)

      package.save

      bits_packer_job = Jobs::Runtime::PackageBits.new(package.guid, message.filepath)
      Jobs::Enqueuer.new(bits_packer_job, queue: Jobs::LocalQueue.new(@config)).enqueue()

      package
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    def show(guid, access_context)
      package = PackageModel.find(guid: guid)
      return nil if package.nil?
      raise Unauthorized if access_context.cannot?(:read,  package)
      package
    end
  end
end
