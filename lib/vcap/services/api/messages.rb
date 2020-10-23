# Copyright (c) 2009-2011 VMware, Inc.
require 'uri'

require 'vcap/services/api/const'
require 'membrane'
require 'vcap/json_message'

module VCAP
  module Services
    module Api
      class EmptyRequest < JsonMessage
      end
      EMPTY_REQUEST = EmptyRequest.new.freeze

      #
      # Tell the CloudController about a service
      # NB: Deleting an offering takes all args in the url
      #
      class ServiceOfferingRequest < JsonMessage
        required :label,        SERVICE_LABEL_REGEX
        required :url,          URI::DEFAULT_PARSER.make_regexp(%w(http https))
        required :supported_versions, [String]
        required :version_aliases, Hash

        optional :description,  String
        optional :info_url,     URI::DEFAULT_PARSER.make_regexp(%w(http https))
        optional :tags,         [String]
        optional :plan_details do
          [
            {
              'name' => String,
              'free' => bool,
              optional('description') => String,
              optional('extra') => String,
              optional('unique_id') => String,
            }
          ]
        end
        optional :plans, [String]
        optional :plan_descriptions
        optional :cf_plan_id
        optional :plan_options
        optional :binding_options
        optional :acls
        optional :active
        optional :timeout,      Integer
        optional :provider,     String
        optional :default_plan, String
        optional :extra,        String
        optional :unique_id,    String
      end

      class ProxiedServiceOfferingRequest < JsonMessage
        required :label,        SERVICE_LABEL_REGEX
        required :options,      [{ 'name' => String, 'credentials' => Hash }]
        optional :description,  String
      end

      class HandleUpdateRequest < JsonMessage
        required :service_id, String
        required :configuration
        required :credentials
      end

      class HandleUpdateRequestV2 < JsonMessage
        required :token, String
        required :gateway_data
        required :credentials
      end

      class ListHandlesResponse < JsonMessage
        required :handles, [Object]
      end

      class ListProxiedServicesResponse < JsonMessage
        required :proxied_services, [{ 'label' => String, 'description' => String, 'acls' => { 'users' => [String], 'wildcards' => [String] } }]
      end

      #
      # Provision a service instance
      # NB: Unprovision takes all args in the url
      #
      class CloudControllerProvisionRequest < JsonMessage
        required :label,   SERVICE_LABEL_REGEX
        required :name,    String
        required :plan,    String
        required :version, String

        optional :plan_option
        optional :provider, String
      end

      class GatewayProvisionRequest < JsonMessage
        required :unique_id,         String
        required :name,              String

        optional :email,             String
        optional :provider,          String
        optional :label,             String
        optional :plan,              String
        optional :version,           String
        optional :organization_guid, String
        optional :space_guid,        String
        optional :plan_option
      end

      # Provision and bind response use the same format
      class GatewayHandleResponse < JsonMessage
        required :service_id,       String
        required :configuration
        required :credentials

        optional :dashboard_url,    String
        optional :syslog_drain_url, String
      end

      #
      # Bind a previously provisioned service to an app
      #
      class CloudControllerBindRequest < JsonMessage
        required :service_id, String
        required :app_id,     Integer
        required :binding_options
      end

      class GatewayBindRequest < JsonMessage
        required :service_id,    String
        required :label,         String
        required :email,         String
        required :binding_options

        optional :app_id,        String
      end

      class GatewayUnbindRequest < JsonMessage
        required :service_id,    String
        required :handle_id,     String
        required :binding_options
      end

      class CloudControllerBindResponse < JsonMessage
        required :label,         SERVICE_LABEL_REGEX
        required :binding_token, String
      end

      # Bind app_name using binding_token
      class BindExternalRequest < JsonMessage
        required :binding_token, String
        required :app_id,        Integer
      end

      class BindingTokenRequest < JsonMessage
        required :service_id, String
        required :binding_options
      end

      class Snapshot < JsonMessage
        required :snapshot_id, String
        required :date,        String
        required :size,        Integer
        required :name,        String
      end

      class SnapshotList < JsonMessage
        required :snapshots, [Object]
      end

      class CreateSnapshotV2Request < JsonMessage
        required :name, /./
      end

      class SnapshotV2 < JsonMessage
        required :snapshot_id,   String
        required :name,          String
        required :state,         String
        required :size,          Integer

        optional :created_time,  String
        optional :restored_time, String
      end

      class SnapshotListV2 < JsonMessage
        required :snapshots, [Object]
      end

      class UpdateSnapshotNameRequest < JsonMessage
        required :name, String
      end

      class Job < JsonMessage
        required :job_id,        String
        required :status,        String
        required :start_time,    String
        optional :description,   String
        optional :complete_time, String
        optional :result,        Object
      end

      class SerializedURL < JsonMessage
        required :url, URI::DEFAULT_PARSER.make_regexp(%w(http https))
      end

      class SerializedData < JsonMessage
        required :data, String
      end

      class ServiceErrorResponse < JsonMessage
        required :code,        Integer
        required :description, String
        optional :error,       Hash
      end
    end
  end
end
