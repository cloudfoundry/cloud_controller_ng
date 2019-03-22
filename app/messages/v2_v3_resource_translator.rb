require 'messages/base_message'
require 'messages/validators'

module VCAP::CloudController
  class V2V3ResourceTranslator
    def initialize(resources)
      @resources = resources
    end

    def v2_fingerprints_body
      resources.map do |resource|
        resource = resource.deep_symbolize_keys
        if v3?(resource)
          {
            sha1: resource[:checksum][:value],
            size: resource[:size_in_bytes],
            fn: resource[:path],
            mode: resource[:mode]
          }
        else
          resource
        end
      end
    end

    private

    attr_reader :resources

    def v3?(resource)
      resource.key?(:checksum) && resource.key?(:size_in_bytes)
    end
  end
end
