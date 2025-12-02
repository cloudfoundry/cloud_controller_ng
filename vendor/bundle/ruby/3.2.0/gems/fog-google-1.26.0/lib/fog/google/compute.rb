module Fog
  module Google
    class Compute < Fog::Service
      autoload :Mock, 'fog/google/compute/mock'
      autoload :Real, 'fog/google/compute/real'

      requires :google_project
      recognizes(
        :app_name,
        :app_version,
        :google_application_default,
        :google_auth,
        :google_client,
        :google_client_options,
        :google_extra_global_projects,
        :google_exclude_projects,
        :google_key_location,
        :google_key_string,
        :google_json_key_location,
        :google_json_key_string
      )

      GOOGLE_COMPUTE_API_VERSION     = "v1".freeze
      GOOGLE_COMPUTE_BASE_URL        = "https://www.googleapis.com/compute/".freeze
      GOOGLE_COMPUTE_API_SCOPE_URLS  = %w(https://www.googleapis.com/auth/compute
                                          https://www.googleapis.com/auth/devstorage.read_write
                                          https://www.googleapis.com/auth/ndev.cloudman
                                          https://www.googleapis.com/auth/cloud-platform).freeze
      GOOGLE_COMPUTE_DEFAULT_NETWORK = "default".freeze

      request_path "fog/google/compute/requests"
      request :add_backend_service_backends
      request :add_instance_group_instances
      request :add_server_access_config
      request :add_target_pool_health_checks
      request :add_target_pool_instances

      request :delete_address
      request :delete_global_address
      request :delete_backend_service
      request :delete_disk
      request :delete_firewall
      request :delete_forwarding_rule
      request :delete_global_forwarding_rule
      request :delete_global_operation
      request :delete_http_health_check
      request :delete_image
      request :delete_instance_group
      request :delete_network
      request :delete_region_operation
      request :delete_route
      request :delete_server
      request :delete_server_access_config
      request :delete_snapshot
      request :delete_subnetwork
      request :delete_target_http_proxy
      request :delete_target_https_proxy
      request :delete_target_instance
      request :delete_target_pool
      request :delete_url_map
      request :delete_zone_operation
      request :delete_ssl_certificate

      request :get_address
      request :get_global_address
      request :get_backend_service
      request :get_backend_service_health
      request :get_disk
      request :get_disk_type
      request :get_firewall
      request :get_forwarding_rule
      request :get_global_forwarding_rule
      request :get_global_operation
      request :get_http_health_check
      request :get_image
      request :get_image_from_family
      request :get_instance_group
      request :get_machine_type
      request :get_network
      request :get_project
      request :get_region
      request :get_region_operation
      request :get_route
      request :get_server
      request :get_server_serial_port_output
      request :get_snapshot
      request :get_subnetwork
      request :get_target_http_proxy
      request :get_target_https_proxy
      request :get_target_instance
      request :get_target_pool
      request :get_target_pool_health
      request :get_url_map
      request :get_zone
      request :get_zone_operation
      request :get_ssl_certificate

      request :insert_address
      request :insert_global_address
      request :insert_backend_service
      request :insert_disk
      request :insert_firewall
      request :insert_forwarding_rule
      request :insert_global_forwarding_rule
      request :insert_http_health_check
      request :insert_image
      request :insert_instance_group
      request :insert_network
      request :insert_route
      request :insert_server
      request :insert_subnetwork
      request :insert_target_http_proxy
      request :insert_target_https_proxy
      request :insert_target_instance
      request :insert_target_pool
      request :insert_url_map
      request :insert_ssl_certificate

      request :list_addresses
      request :list_aggregated_addresses
      request :list_aggregated_disk_types
      request :list_aggregated_disks
      request :list_aggregated_forwarding_rules
      request :list_aggregated_instance_groups
      request :list_aggregated_machine_types
      request :list_aggregated_servers
      request :list_aggregated_subnetworks
      request :list_aggregated_target_instances
      request :list_aggregated_target_pools
      request :list_backend_services
      request :list_disk_types
      request :list_disks
      request :list_firewalls
      request :list_forwarding_rules
      request :list_global_addresses
      request :list_global_forwarding_rules
      request :list_global_operations
      request :list_http_health_checks
      request :list_images
      request :list_instance_group_instances
      request :list_instance_groups
      request :list_machine_types
      request :list_networks
      request :list_region_operations
      request :list_regions
      request :list_routes
      request :list_servers
      request :list_snapshots
      request :list_subnetworks
      request :list_target_http_proxies
      request :list_target_https_proxies
      request :list_target_instances
      request :list_target_pools
      request :list_url_maps
      request :list_zone_operations
      request :list_zones
      request :list_ssl_certificates

      request :patch_firewall
      request :patch_url_map

      request :remove_instance_group_instances
      request :remove_target_pool_health_checks
      request :remove_target_pool_instances

      request :set_common_instance_metadata
      request :set_forwarding_rule_target
      request :set_global_forwarding_rule_target
      request :set_server_disk_auto_delete
      request :set_server_machine_type
      request :set_server_metadata
      request :set_server_scheduling
      request :set_server_tags
      request :set_snapshot_labels
      request :set_subnetwork_private_ip_google_access
      request :set_target_http_proxy_url_map
      request :set_target_https_proxy_ssl_certificates
      request :set_target_https_proxy_url_map
      request :set_target_pool_backup

      request :update_firewall
      request :update_http_health_check
      request :update_url_map

      request :attach_disk
      request :detach_disk
      request :create_disk_snapshot

      request :expand_subnetwork_ip_cidr_range
      request :reset_server
      request :start_server
      request :stop_server

      request :invalidate_url_map_cache
      request :validate_url_map

      request :get_instance_group_manager
      request :insert_instance_group_manager
      request :delete_instance_group_manager
      request :list_instance_templates
      request :list_instance_group_managers
      request :get_instance_template
      request :insert_instance_template
      request :delete_instance_template

      request :list_aggregated_instance_group_managers
      request :set_instance_template
      request :recreate_instances
      request :abandon_instances

      request :deprecate_image

      request :reset_windows_password

      model_path "fog/google/compute/models"
      model :server
      collection :servers

      model :image
      collection :images

      model :disk
      collection :disks

      model :disk_type
      collection :disk_types

      model :machine_type
      collection :machine_types

      model :address
      collection :addresses

      model :global_address
      collection :global_addresses

      model :operation
      collection :operations

      model :snapshot
      collection :snapshots

      model :zone
      collection :zones

      model :region
      collection :regions

      model :http_health_check
      collection :http_health_checks

      model :target_pool
      collection :target_pools

      model :forwarding_rule
      collection :forwarding_rules

      model :project
      collection :projects

      model :firewall
      collection :firewalls

      model :network
      collection :networks

      model :route
      collection :routes

      model :backend_service
      collection :backend_services

      model :target_http_proxy
      collection :target_http_proxies

      model :target_https_proxy
      collection :target_https_proxies

      model :url_map
      collection :url_maps

      model :global_forwarding_rule
      collection :global_forwarding_rules

      model :target_instance
      collection :target_instances

      model :instance_group
      collection :instance_groups

      model :subnetwork
      collection :subnetworks

      model :instance_template
      collection :instance_templates

      model :instance_group_manager
      collection :instance_group_managers

      model :ssl_certificate
      collection :ssl_certificates
    end
  end
end
