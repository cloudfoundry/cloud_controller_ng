require "fog/core/model"

module Fog
  module Google
    class Monitoring
      ##
      # A monitoredResourceDescriptor defines a metric type and its schema.
      #
      # @see https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.monitoredResourceDescriptors#MonitoredResourceDescriptor
      class MonitoredResourceDescriptor < Fog::Model
        identity :name

        attribute :description
        attribute :display_name, :aliases => "displayName"
        attribute :type
        attribute :labels
      end
    end
  end
end
