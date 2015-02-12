module VCAP::CloudController
  class StagingMessage
    attr_reader :package_guid, :buildpack_guid, :buildpack_git_url
    attr_accessor :error

    def self.create_from_http_request(package_guid, body)
      opts = body && MultiJson.load(body)
      opts = {} unless opts.is_a?(Hash)
      StagingMessage.new(package_guid, opts)
    rescue MultiJson::ParseError => e
      message = StagingMessage.new(package_guid, {})
      message.error = e.message
      message
    end

    def initialize(package_guid, opts)
      @package_guid      = package_guid
      @memory_limit      = opts['memory_limit']
      @disk_limit        = opts['disk_limit']
      @stack             = opts['stack']
      @buildpack_guid    = opts['buildpack_guid']
      @buildpack_git_url = opts['buildpack_git_url']

      @config = Config.config
    end

    def validate
      return false, [error] if error
      errors = []
      errors << validate_memory_limit_field
      errors << validate_disk_limit_field
      errors << validate_stack_field
      errors << validate_buildpack_fields
      errors << validate_buildpack_guid_field
      errors << validate_buildpack_git_url_field
      errs = errors.compact
      [errs.length == 0, errs]
    end

    def stack
      @stack ||= Stack.default.name
    end

    def memory_limit
      [@memory_limit, default_memory_limit].compact.max
    end

    def disk_limit
      [@disk_limit, default_disk_limit].compact.max
    end

    private

    def default_disk_limit
      @config[:staging][:minimum_staging_disk_mb] || 4096
    end

    def default_memory_limit
      (@config[:staging] && @config[:staging][:minimum_staging_memory_mb] || 1024)
    end

    def validate_memory_limit_field
      return 'The memory_limit field must be an Integer' unless @memory_limit.is_a?(Integer) || @memory_limit.nil?
      nil
    end

    def validate_disk_limit_field
      return 'The disk_limit field must be an Integer' unless @disk_limit.is_a?(Integer) || @disk_limit.nil?
      nil
    end

    def validate_stack_field
      return 'The stack field must be a String' unless @stack.is_a?(String) || @stack.nil?
      nil
    end

    def validate_buildpack_guid_field
      return 'The buildpack_guid field must be a String' unless @buildpack_guid.is_a?(String) || @buildpack_guid.nil?
      nil
    end

    def validate_buildpack_git_url_field
      return 'The buildpack_git_url field must be a valid URI' unless @buildpack_git_url =~ /\A#{URI.regexp}\Z/ || @buildpack_git_url.nil?
      nil
    end

    def validate_buildpack_fields
      return 'Only one of buildpack_git_url or buildpack_guid may be provided' if !@buildpack_git_url.nil? && !@buildpack_guid.nil?
    end
  end

  class DropletsHandler
    class Unauthorized < StandardError; end
    class PackageNotFound < StandardError; end
    class SpaceNotFound < StandardError; end
    class BuildpackNotFound < StandardError; end
    class InvalidRequest < StandardError; end

    def initialize(config, stagers, paginator=SequelPaginator.new)
      @config = config
      @stagers = stagers
      @paginator = paginator
    end

    def create(message, access_context)
      package = PackageModel.find(guid: message.package_guid)
      raise PackageNotFound if package.nil?
      raise InvalidRequest.new('Cannot stage package whose state is not ready.') if package.state != PackageModel::READY_STATE
      raise InvalidRequest.new('Cannot stage package whose type is not bits.') if package.type != PackageModel::BITS_TYPE

      space = Space.find(guid: package.space_guid)
      raise SpaceNotFound if space.nil?

      droplet = DropletModel.new(
        app_guid: package.app_guid,
        buildpack_git_url: message.buildpack_git_url,
        buildpack_guid: message.buildpack_guid,
        package_guid: package.guid,
        state: DropletModel::PENDING_STATE,
      )
      raise Unauthorized if access_context.cannot?(:create, droplet, space)

      buildpack_key = nil
      if message.buildpack_guid
        buildpack = Buildpack.find(guid: message.buildpack_guid)
        raise BuildpackNotFound if buildpack.nil?
        buildpack_key = buildpack.key
      end

      droplet.save

      @stagers.stager_for_package(package).stage_package(droplet, message.stack, message.memory_limit, message.disk_limit, buildpack_key, message.buildpack_git_url)
      droplet
    end

    def show(guid, access_context)
      droplet = DropletModel.find(guid: guid)
      return nil if droplet.nil?
      package = PackageModel.find(guid: droplet.package_guid)
      raise Unauthorized if access_context.cannot?(:read, droplet, package)
      droplet
    end

    def list(pagination_options, access_context)
      dataset = nil
      if access_context.roles.admin?
        dataset = DropletModel.dataset
      else
        dataset = DropletModel.user_visible(access_context.user)
      end

      @paginator.get_page(dataset, pagination_options)
    end

    def delete(access_context, filter: {})
      dataset = DropletModel.dataset

      allowed_filters = %i(app_guid guid)
      return [] if (filter.keys - allowed_filters).size > 0

      filter.each do |column, value|
        dataset = dataset.where(:"#{DropletModel.table_name}__#{column}" => value)
      end

      dataset.map do |droplet|
        inner_delete(droplet, access_context)
      end
    end

    private

    def inner_delete(droplet, access_context)
      package = PackageModel.find(guid: droplet.package_guid)
      space = Space.find(guid: package.space_guid)

      droplet.db.transaction do
        droplet.lock!
        raise Unauthorized if access_context.cannot?(:delete, droplet, space)
        droplet.destroy
      end

      key = droplet.blobstore_key
      blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(key, :droplet_blobstore, nil)
      Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue

      droplet
    end
  end
end
