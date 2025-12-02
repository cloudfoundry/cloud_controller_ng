require 'fog/core'
require 'fog/json'

module Fog
  module OpenStack
    require 'fog/openstack/auth/token'

    autoload :VERSION, 'fog/openstack/version'

    autoload :Core, 'fog/openstack/core'
    autoload :Errors, 'fog/openstack/errors'

    autoload :Baremetal, 'fog/openstack/baremetal'
    autoload :Compute, 'fog/openstack/compute'
    autoload :ContainerInfra, 'fog/openstack/container_infra'
    autoload :DNS, 'fog/openstack/dns'
    autoload :Event, 'fog/openstack/event'
    autoload :Identity, 'fog/openstack/identity'
    autoload :Image, 'fog/openstack/image'
    autoload :Introspection, 'fog/openstack/introspection'
    autoload :KeyManager, 'fog/openstack/key_manager'
    autoload :Metering, 'fog/openstack/metering'
    autoload :Metric, 'fog/openstack/metric'
    autoload :Monitoring, 'fog/openstack/monitoring'
    autoload :Network, 'fog/openstack/network'
    autoload :NFV, 'fog/openstack/nfv'
    autoload :Orchestration, 'fog/openstack/orchestration'
    autoload :OrchestrationUtil, 'fog/openstack/orchestration/util/recursive_hot_file_loader'
    autoload :Planning, 'fog/openstack/planning'
    autoload :SharedFileSystem, 'fog/openstack/shared_file_system'
    autoload :Storage, 'fog/openstack/storage'
    autoload :Workflow, 'fog/openstack/workflow'
    autoload :Volume, 'fog/openstack/volume'

    extend Fog::Provider

    service(:baremetal,          'Baremetal')
    service(:compute,            'Compute')
    service(:container_infra,    'ContainerInfra')
    service(:dns,                'DNS')
    service(:event,              'Event')
    service(:identity,           'Identity')
    service(:image,              'Image')
    service(:introspection,      'Introspection')
    service(:key,                'KeyManager')
    service(:metering,           'Metering')
    service(:metric,             'Metric')
    service(:monitoring,         'Monitoring')
    service(:network,            'Network')
    service(:nfv,                'NFV')
    service(:orchestration,      'Orchestration')
    service(:planning,           'Planning')
    service(:shared_file_system, 'SharedFileSystem')
    service(:storage,            'Storage')
    service(:volume,             'Volume')
    service(:workflow,           'Workflow')

    @token_cache = {}

    class << self
      attr_accessor :token_cache
    end

    def self.clear_token_cache
      Fog::OpenStack.token_cache = {}
    end

    def self.endpoint_region?(endpoint, region)
      region.nil? || endpoint['region'] == region
    end

    def self.get_supported_version(supported_versions, uri, auth_token, connection_options = {})
      supported_version = get_version(supported_versions, uri, auth_token, connection_options)
      version = supported_version['id'] if supported_version
      version_raise(supported_versions) if version.nil?

      version
    end

    def self.get_supported_version_path(supported_versions, uri, auth_token, connection_options = {})
      supported_version = get_version(supported_versions, uri, auth_token, connection_options)
      link = supported_version['links'].find { |l| l['rel'] == 'self' } if supported_version
      path = URI.parse(link['href']).path if link
      version_raise(supported_versions) if path.nil?

      path.chomp '/'
    end

    def self.get_supported_microversion(supported_versions, uri, auth_token, connection_options = {})
      supported_version = get_version(supported_versions, uri, auth_token, connection_options)
      supported_version['version'] if supported_version
    end

    # CGI.escape, but without special treatment on spaces
    def self.escape(str, extra_exclude_chars = '')
      str.gsub(/([^a-zA-Z0-9_.-#{extra_exclude_chars}]+)/) do
        '%' + $1.unpack('H2' * $1.bytesize).join('%').upcase
      end
    end

    def self.get_version(supported_versions, uri, auth_token, connection_options = {})
      version_cache = "#{uri}#{supported_versions}"
      return @version[version_cache] if @version && @version[version_cache]

      # To allow version discovery we need a "version less" endpoint
      path = uri.path.gsub(/\/v([1-9]+\d*)(\.[1-9]+\d*)*.*$/, '/')
      url = "#{uri.scheme}://#{uri.host}:#{uri.port}#{path}"
      connection = Fog::Core::Connection.new(url, false, connection_options)
      response = connection.request(
        :expects => [200, 204, 300],
        :headers => {'Content-Type' => 'application/json',
                     'Accept'       => 'application/json',
                     'X-Auth-Token' => auth_token},
        :method  => 'GET'
      )

      body = Fog::JSON.decode(response.body)

      @version                = {} unless @version
      @version[version_cache] = extract_version_from_body(body, supported_versions)
    end

    def self.extract_version_from_body(body, supported_versions)
      versions = []
      unless body['versions'].nil? || body['versions'].empty?
        versions = body['versions'].kind_of?(Array) ? body['versions'] : body['versions']['values']
      end
      # Some version API would return single endpoint rather than endpoints list, try to get it via 'version'.
      unless body['version'].nil? or versions.length != 0
        versions = [body['version']]
      end
      version = nil

      # order is important, preferred status should be first
      %w(CURRENT stable SUPPORTED DEPRECATED).each do |status|
        version = versions.find { |x| x['id'].match(supported_versions) && (x['status'] == status) }
        break if version
      end

      version
    end

    def self.version_raise(supported_versions)
      raise Fog::OpenStack::Errors::ServiceUnavailable,
            "OpenStack service only supports API versions #{supported_versions.inspect}"
    end
  end
end
