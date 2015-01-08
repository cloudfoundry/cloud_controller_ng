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
      [errs.length == 0, errs]
    end

    private

    def validate_type_field
      return 'The type field is required' if @type.nil?
      valid_type_fields = %w(bits docker)

      if !valid_type_fields.include?(@type)
        return "The type field needs to be one of '#{valid_type_fields.join(', ')}'"
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
    class AppNotFound < StandardError; end

    PACKAGE_STATES = %w(PENDING READY FAILED).map(&:freeze).freeze

    def initialize(config)
      @config = config
    end

    def create(message, access_context)
      package          = PackageModel.new
      package.app_guid = message.app_guid
      package.type     = message.type
      package.state    = 'READY' if message.type == 'docker'

      app = AppModel.find(guid: package.app_guid)
      raise AppNotFound if app.nil?

      space = Space.find(guid: app.space_guid)

      app.db.transaction do
        app.lock!

        raise Unauthorized if access_context.cannot?(:create, package, app, space)

        package.save
      end

      if package.type == 'bits'
        bits_packer_job = Jobs::Runtime::PackageBits.new(package.guid, message.filepath)
        Jobs::Enqueuer.new(bits_packer_job, queue: Jobs::LocalQueue.new(@config)).enqueue
      end

      package
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    def delete(guid, access_context)
      package = PackageModel.find(guid: guid)
      return nil if package.nil?

      app = AppModel.find(guid: package.app_guid)
      space = Space.find(guid: app.space_guid)

      package.db.transaction do
        app.lock!

        raise Unauthorized if access_context.cannot?(:delete, package, app, space)

        package.destroy
      end

      blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(package.guid, :package_blobstore, nil)
      Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue

      package
    end

    def show(guid, access_context)
      package = PackageModel.find(guid: guid)
      return nil if package.nil?
      raise Unauthorized if access_context.cannot?(:read,  package)
      package
    end
  end
end
