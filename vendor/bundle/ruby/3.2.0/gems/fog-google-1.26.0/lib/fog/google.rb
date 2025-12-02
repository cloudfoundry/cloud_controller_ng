require "fog/core"
require "fog/json"
require "fog/xml"
require "fog/google/version"

module Fog
  module Google
    autoload :Compute, File.expand_path("../google/compute", __FILE__)
    autoload :DNS, File.expand_path("../google/dns", __FILE__)
    autoload :Mock, File.expand_path("../google/mock", __FILE__)
    autoload :Monitoring, File.expand_path("../google/monitoring", __FILE__)
    autoload :Pubsub, File.expand_path("../google/pubsub", __FILE__)
    autoload :Shared, File.expand_path("../google/shared", __FILE__)
    autoload :SQL, File.expand_path("../google/sql", __FILE__)
    autoload :Storage, File.expand_path("../google/storage", __FILE__)
    autoload :StorageJSON, 'fog/google/storage/storage_json'
    autoload :StorageXML, 'fog/google/storage/storage_xml'

    extend Fog::Provider

    service(:compute, "Compute")
    service(:dns, "DNS")
    service(:monitoring, "Monitoring")
    service(:pubsub, "Pubsub")
    service(:storage, "Storage")
    service(:sql, "SQL")

    # CGI.escape, but without special treatment on spaces
    def self.escape(str, extra_exclude_chars = "")
      # '-' is a special character inside a regex class so it must be first or last.
      # Add extra excludes before the final '-' so it always remains trailing, otherwise
      # an unwanted range is created by mistake.
      str.gsub(/([^a-zA-Z0-9_.#{extra_exclude_chars}-]+)/) do
        "%" + Regexp.last_match(1).unpack("H2" * Regexp.last_match(1).bytesize).join("%").upcase
      end
    end

    module Parsers
      autoload :Storage, 'fog/google/parsers/storage'
    end
  end
end

# Add shims for backward compatibility
# This allows old style references like Fog::Compute::Google to work
# by redirecting them to the new namespace Fog::Google::Compute

module Fog
  # List of services from the original module
  GOOGLE_SERVICES = %w[Compute DNS Monitoring Pubsub Storage SQL]

  # Dynamically create shim modules for each service
  GOOGLE_SERVICES.each do |service|
    # Create the module namespace
    const_set(service, Module.new) unless const_defined?(service)

    # Get reference to the module
    service_module = const_get(service)

    # Define the Google submodule with the shim
    service_module.const_set(:Google, Module.new)
    service_module::Google.define_singleton_method(:new) do |*args|
      warn "[DEPRECATION] `Fog::#{service}::Google.new` is deprecated. Please use `Fog::Google::#{service}.new` instead."
      Fog::Google.const_get(service).new(*args)
    end
  end
end
