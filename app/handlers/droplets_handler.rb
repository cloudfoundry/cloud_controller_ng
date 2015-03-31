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
    class AppNotFound < StandardError; end
    class BuildpackNotFound < StandardError; end
    class InvalidRequest < StandardError; end

    def initialize(config, stagers, paginator=SequelPaginator.new)
      @config = config
      @stagers = stagers
      @paginator = paginator
    end

    def show(guid, access_context)
      droplet = DropletModel.find(guid: guid)
      return nil if droplet.nil?
      app_model = AppModel.find(guid: droplet.app_guid)
      raise Unauthorized if access_context.cannot?(:read, droplet, app_model)
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

    private

    def vcap_application(message, app_model, space)
      version = SecureRandom.uuid
      uris = app_model.routes.map(&:fqdn)
      {
        limits: {
          mem: message.memory_limit,
          disk: message.disk_limit,
          fds: Config.config[:instance_file_descriptor_limit] || 16384,
        },
        application_version: version,
        application_name: app_model.name,
        application_uris: uris,
        version: version,
        name: app_model.name,
        space_name: space.name,
        space_id: space.guid,
        uris: uris,
        users: nil
      }
    end
  end
end
