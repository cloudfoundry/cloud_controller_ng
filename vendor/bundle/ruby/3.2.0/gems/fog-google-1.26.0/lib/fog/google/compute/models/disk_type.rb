module Fog
  module Google
    class Compute
      class DiskType < Fog::Model
        identity :name

        attribute :kind
        attribute :id
        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :default_disk_size_gb, :aliases => "defaultDiskSizeGb"
        attribute :deprecated
        attribute :description
        attribute :self_link, :aliases => "selfLink"
        attribute :valid_disk_size, :aliases => "validDiskSize"
        attribute :zone

        def reload
          requires :identity, :zone

          data = collection.get(identity, zone)
          merge_attributes(data.attributes)
          self
        end
      end
    end
  end
end
