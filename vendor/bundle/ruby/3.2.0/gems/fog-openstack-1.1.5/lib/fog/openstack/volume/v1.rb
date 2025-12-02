require 'fog/openstack/core'
require 'fog/openstack/volume'

module Fog
  module OpenStack
    class Volume
      class V1 < Fog::OpenStack::Volume
        SUPPORTED_VERSIONS = /v1(\.(0-9))*/

        requires :openstack_auth_url

        recognizes *@@recognizes

        model_path 'fog/openstack/volume/v1/models'

        model :volume
        collection :volumes

        model :availability_zone
        collection :availability_zones

        model :volume_type
        collection :volume_types

        model :snapshot
        collection :snapshots

        model :transfer
        collection :transfers

        model :backup
        collection :backups

        request_path 'fog/openstack/volume/v1/requests'

        # Volume
        request :list_volumes
        request :list_volumes_detailed
        request :create_volume
        request :update_volume
        request :get_volume_details
        request :extend_volume
        request :delete_volume

        request :list_zones

        request :list_volume_types
        request :create_volume_type
        request :delete_volume_type
        request :get_volume_type_details

        request :create_snapshot
        request :update_snapshot
        request :list_snapshots
        request :list_snapshots_detailed
        request :get_snapshot_details
        request :delete_snapshot
        request :update_snapshot_metadata
        request :delete_snapshot_metadata

        request :list_transfers
        request :list_transfers_detailed
        request :create_transfer
        request :get_transfer_details
        request :accept_transfer
        request :delete_transfer

        request :list_backups
        request :list_backups_detailed
        request :create_backup
        request :get_backup_details
        request :restore_backup
        request :delete_backup

        request :update_quota
        request :get_quota
        request :get_quota_defaults
        request :get_quota_usage

        request :update_metadata
        request :replace_metadata
        request :delete_metadata

        request :set_tenant
        request :action

        autoload :Mock, 'fog/openstack/volume/v1/mock'
        autoload :Real, 'fog/openstack/volume/v1/real'
      end
    end
  end
end
