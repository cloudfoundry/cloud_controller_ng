# frozen_string_literal: true

require 'addressable'

module Fog
  module Compute
    class Aliyun < Fog::Service
      recognizes :aliyun_url,
                 :aliyun_accesskey_id,
                 :aliyun_accesskey_secret,
                 :aliyun_region_id,
                 :aliyun_zone_id

      ## MODELS
      #
      model_path 'fog/aliyun/models/compute'
      model :server
      collection :servers
      model :image
      collection :images
      model :eip_address
      collection :eip_addresses
      model :security_group
      collection :security_groups
      model :security_group_rule
      collection :security_group_rules
      model :volume
      collection :volumes
      model :snapshot
      collection :snapshots
      model :vpc
      collection :vpcs
      model :vswitch
      collection :vswitches
      model :vrouter
      collection :vrouters
      model :route_table
      collection :route_tables
      model :route_entry
      collection :route_entrys
      model :flavor
      collection :flavors
      ## REQUESTS
      #
      request_path 'fog/aliyun/requests/compute'

      # Server CRUD
      request :list_servers
      request :list_server_types
      request :create_server
      request :delete_server

      # Server Actions
      request :reboot_server
      request :start_server
      request :stop_server

      # SnapShoot CRUD
      request :list_snapshots
      request :create_snapshot
      request :delete_snapshot

      # Image CRUD
      request :list_images
      request :create_image
      request :delete_image

      # Eip
      request :list_eip_addresses
      request :allocate_eip_address
      request :release_eip_address
      request :associate_eip_address
      request :unassociate_eip_address

      # Security Group
      request :list_security_groups
      request :list_security_group_rules
      request :create_security_group
      request :create_security_group_ip_rule
      request :create_security_group_sg_rule
      request :create_security_group_egress_ip_rule
      request :create_security_group_egress_sg_rule
      request :delete_security_group
      request :delete_security_group_ip_rule
      request :delete_security_group_sg_rule
      request :delete_security_group_egress_ip_rule
      request :delete_security_group_egress_sg_rule
      request :join_security_group
      request :leave_security_group

      # Zones
      request :list_zones

      # VPC
      request :create_vpc
      request :delete_vpc
      request :list_vpcs
      request :create_vswitch
      request :delete_vswitch
      request :list_vswitchs
      request :modify_vpc
      request :modify_vswitch
      request :list_vpn_gateways
      request :list_vpn_customergateways
      request :list_vpn_connections
      request :create_vpn_customergateway
      request :create_vpn_connection
      request :delete_vpn_customergateway
      request :delete_vpn_connection
      # VRouter
      request :list_vrouters

      # RouteTable
      request :list_route_tables

      # clouddisk
      request :list_disks
      request :create_disk
      request :delete_disk
      request :attach_disk
      request :detach_disk

      # PublicIpAddress
      request :allocate_public_ip_address

      class Mock
        attr_reader :auth_token
        attr_reader :auth_token_expiration
        attr_reader :current_user
        attr_reader :current_tenant

        def self.data
          @data ||= Hash.new do |hash, key|
            hash[key] = {
              last_modified: {
                images: {},
                servers: {},
                key_pairs: {},
                security_groups: {},
                addresses: {}
              },
              images: {
                '0e09fbd6-43c5-448a-83e9-0d3d05f9747e' => {
                  'id' => '0e09fbd6-43c5-448a-83e9-0d3d05f9747e',
                  'name' => 'cirros-0.3.0-x86_64-blank',
                  'progress'  => 100,
                  'status'    => 'ACTIVE',
                  'updated'   => '',
                  'minRam'    => 0,
                  'minDisk'   => 0,
                  'metadata'  => {},
                  'links'     => [{ 'href' => 'http://nova1:8774/v1.1/admin/images/1', 'rel' => 'self' }, { 'href' => 'http://nova1:8774/admin/images/2', 'rel' => 'bookmark' }]
                }
              },
              servers: {},
              key_pairs: {},
              security_groups: {
                '0' => {
                  'id'          => 0,
                  'tenant_id'   => Fog::Mock.random_hex(8),
                  'name'        => 'default',
                  'description' => 'default',
                  'rules'       => [
                    { 'id'              => 0,
                      'parent_group_id' => 0,
                      'from_port'       => 68,
                      'to_port'         => 68,
                      'ip_protocol'     => 'udp',
                      'ip_range'        => { 'cidr' => '0.0.0.0/0' },
                      'group'           => {} }
                  ]
                }
              },
              server_security_group_map: {},
              addresses: {},
              quota: {
                'security_group_rules' => 20,
                'security_groups' => 10,
                'injected_file_content_bytes' => 10_240,
                'injected_file_path_bytes' => 256,
                'injected_files' => 5,
                'metadata_items' => 128,
                'floating_ips'   => 10,
                'instances'      => 10,
                'key_pairs'      => 10,
                'gigabytes'      => 5000,
                'volumes'        => 10,
                'cores'          => 20,
                'ram'            => 51_200
              },
              volumes: {}
            }
          end
        end

        def self.reset
          @data = nil
        end

        def initialize(options = {})
          @aliyun_username = options[:aliyun_username]
          @aliyun_user_domain = options[:aliyun_user_domain] || options[:aliyun_domain]
          @aliyun_project_domain = options[:aliyun_project_domain] || options[:aliyun_domain] || 'Default'

          raise ArgumentError, 'Missing required arguments: :aliyun_auth_url' unless options.key?[:aliyun_auth_url]
          @aliyun_auth_uri = URI.parse(options[:aliyun_auth_url])

          @current_tenant = options[:aliyun_tenant]
          @current_tenant_id = options[:aliyun_tenant_id]

          @auth_token = Fog::Mock.random_base64(64)
          @auth_token_expiration = (Time.now.utc + 86_400).iso8601

          management_url = URI.parse(@aliyun_auth_url)
          management_url.port = 8774
          management_url.path = '/v1.1/1'
          @aliyun_management_url = management_url.to_s

          identity_public_endpoint = URI.parse(@aliyun_auth_url)
          identity_public_endpoint.port = 5000
          @aliyun_identity_public_endpoint = identity_public_endpoint.to_s
        end

        def data
          self.class.data["#{@aliyun_username}-#{@current_tenant}"]
        end

        def reset_data
          self.class.data.delete("#{@aliyun_username}-#{@current_tenant}")
        end

        def credentials
          { provider: 'aliyun',
            aliyun_auth_url: @aliyun_auth_uri.to_s,
            aliyun_auth_token: @auth_token,
            aliyun_management_url: @aliyun_management_url,
            aliyun_identity_endpoint: @aliyun_identity_public_endpoint }
        end
      end

      class Real
        # Initialize connection to ECS
        #
        # ==== Notes
        # options parameter must include values for :aliyun_url, :aliyun_accesskey_id,
        # :aliyun_secret_access_key, :aliyun_region_id and :aliyun_zone_id in order to create a connection.
        # if you haven't set these values in the configuration file.
        #
        # ==== Examples
        #   sdb = Fog::Compute.new(:provider=>'aliyun',
        #    :aliyun_accesskey_id => your_:aliyun_accesskey_id,
        #    :aliyun_secret_access_key => your_aliyun_secret_access_key
        #   )
        #
        # ==== Parameters
        # * options<~Hash> - config arguments for connection.  Defaults to {}.
        #
        # ==== Returns
        # * ECS object with connection to aliyun.
        attr_reader :aliyun_accesskey_id
        attr_reader :aliyun_accesskey_secret
        attr_reader :aliyun_region_id
        attr_reader :aliyun_url
        attr_reader :aliyun_zone_id

        def initialize(options = {})
          # initialize the parameters
          @aliyun_url = options[:aliyun_url]
          @aliyun_accesskey_id = options[:aliyun_accesskey_id]
          @aliyun_accesskey_secret = options[:aliyun_accesskey_secret]
          @aliyun_region_id = options[:aliyun_region_id]
          @aliyun_zone_id = options[:aliyun_zone_id]

          # check for the parameters
          missing_credentials = []
          missing_credentials << :aliyun_accesskey_id unless @aliyun_accesskey_id
          missing_credentials << :aliyun_accesskey_secret unless @aliyun_accesskey_secret
          missing_credentials << :aliyun_region_id unless @aliyun_region_id
          missing_credentials << :aliyun_url unless @aliyun_url
          raise ArgumentError, "Missing required arguments: #{missing_credentials.join(', ')}" unless missing_credentials.empty?

          @connection_options = options[:connection_options] || {}

          uri = URI.parse(@aliyun_url)
          @host = uri.host
          @path = uri.path
          @port = uri.port
          @scheme = uri.scheme

          vpcuri = URI.parse('https://vpc.aliyuncs.com')
          @vpchost = vpcuri.host
          @vpcpath = vpcuri.path
          @vpcport = vpcuri.port
          @vpcscheme = vpcuri.scheme

          @persistent = options[:persistent] || false
          @connection = Fog::Core::Connection.new("#{@scheme}://#{@host}:#{@port}", @persistent, @connection_options)
          @VPCconnection = Fog::Core::Connection.new("#{@vpcscheme}://#{@vpchost}:#{@vpcport}", @persistent, @connection_options)
        end

        def reload
          @connection.reset
          @VPCconnection.reset
        end

        def request(params)
          begin
            response = @connection.request(params.merge(headers: {
              'Content-Type' => 'application/json',
              'Accept' => 'application/json',
              'X-Auth-Token' => @auth_token
            }.merge!(params[:headers] || {}),
                                                        path: "#{@path}/#{params[:path]}",
                                                        query: params[:query]))
          rescue Excon::Errors::HTTPStatusError => error
            raise case error
                  when Excon::Errors::NotFound
                    Fog::Compute::Aliyun::NotFound.slurp(error)
                  else
                    error
                  end
          end

          response.body = Fog::JSON.decode(response.body) if !response.body.empty? && response.get_header('Content-Type') == 'application/json'

          response
        end

        def VPCrequest(params)
          begin
            response = @VPCconnection.request(params.merge(headers: {
              'Content-Type' => 'application/json',
              'Accept' => 'application/json',
              'X-Auth-Token' => @auth_token
            }.merge!(params[:headers] || {}),
                                                           path: "#{@path}/#{params[:path]}",
                                                           query: params[:query]))
          rescue Excon::Errors::HTTPStatusError => error
            raise case error
                  when Excon::Errors::NotFound
                    Fog::Compute::Aliyun::NotFound.slurp(error)
                  else
                    error
                  end
          end

          response.body = Fog::JSON.decode(response.body) if !response.body.empty? && response.get_header('Content-Type') == 'application/json'

          response
        end

        # operation compute-- default URL
        def defaultAliyunUri(action, sigNonce, time)
          parTimeFormat = time.strftime('%Y-%m-%dT%H:%M:%SZ')
          urlTimeFormat = Addressable::URI.encode_component(parTimeFormat, Addressable::URI::CharacterClasses::UNRESERVED + '|')
          '?Format=JSON&AccessKeyId=' + @aliyun_accesskey_id + '&Action=' + action + '&SignatureMethod=HMAC-SHA1&RegionId=' + @aliyun_region_id + '&SignatureNonce=' + sigNonce + '&SignatureVersion=1.0&Version=2014-05-26&Timestamp=' + urlTimeFormat
        end

        def defaultAliyunQueryParameters(action, sigNonce, time)
          {
            Format: 'JSON',
            AccessKeyId: @aliyun_accesskey_id,
            Action: action,
            SignatureMethod: 'HMAC-SHA1',
            RegionId: @aliyun_region_id,
            SignatureNonce: sigNonce,
            SignatureVersion: '1.0',
            Version: '2014-05-26',
            Timestamp: time.strftime('%Y-%m-%dT%H:%M:%SZ')
          }
        end

        def defaultAliyunVPCUri(action, sigNonce, time)
          parTimeFormat = time.strftime('%Y-%m-%dT%H:%M:%SZ')
          urlTimeFormat = Addressable::URI.encode_component(parTimeFormat, Addressable::URI::CharacterClasses::UNRESERVED + '|')
          '?Format=JSON&AccessKeyId=' + @aliyun_accesskey_id + '&Action=' + action + '&SignatureMethod=HMAC-SHA1&RegionId=' + @aliyun_region_id + '&SignatureNonce=' + sigNonce + '&SignatureVersion=1.0&Version=2016-04-28&Timestamp=' + urlTimeFormat
        end

        # generate random num
        def randonStr
          numStr = rand(100_000).to_s
          timeStr = Time.now.to_f.to_s
          ranStr = timeStr + '-' + numStr
          ranStr
        end

        # operation compute--collection of default parameters
        def defaultParameters(action, sigNonce, time)
          parTimeFormat = time.strftime('%Y-%m-%dT%H:%M:%SZ')
          para = {
            'Format' => 'JSON',
            'Version' => '2014-05-26',
            'Action' => action,
            'AccessKeyId' => @aliyun_accesskey_id,
            'SignatureVersion' => '1.0',
            'SignatureMethod' => 'HMAC-SHA1',
            'SignatureNonce' => sigNonce,
            'RegionId' => @aliyun_region_id,
            'Timestamp' => parTimeFormat
          }
          para
        end

        def defalutVPCParameters(action, sigNonce, time)
          parTimeFormat = time.strftime('%Y-%m-%dT%H:%M:%SZ')
          para = {
            'Format' => 'JSON',
            'Version' => '2016-04-28',
            'Action' => action,
            'AccessKeyId' => @aliyun_accesskey_id,
            'SignatureVersion' => '1.0',
            'SignatureMethod' => 'HMAC-SHA1',
            'SignatureNonce' => sigNonce,
            'RegionId' => @aliyun_region_id,
            'Timestamp' => parTimeFormat
          }
          para
        end

        # compute signature
        # This method should be considered deprecated and replaced with sign_without_encoding, which is better for using querystring hashes and not
        # building querystrings with string concatination.
        def sign(accessKeySecret, parameters)
          signature = sign_without_encoding(accessKeySecret, parameters)
          Addressable::URI.encode_component(signature, Addressable::URI::CharacterClasses::UNRESERVED + '|')
        end

        def sign_without_encoding(accessKeySecret, parameters)
          sortedParameters = parameters.sort
          canonicalizedQueryString = ''
          sortedParameters.each do |k, v|
            canonicalizedQueryString += '&' + Addressable::URI.encode_component(k, Addressable::URI::CharacterClasses::UNRESERVED + '|') + '=' + Addressable::URI.encode_component(v, Addressable::URI::CharacterClasses::UNRESERVED + '|')
          end

          canonicalizedQueryString[0] = ''
          stringToSign = 'GET&%2F&' + Addressable::URI.encode_component(canonicalizedQueryString, Addressable::URI::CharacterClasses::UNRESERVED + '|')
          key = accessKeySecret + '&'

          digVer = OpenSSL::Digest.new('sha1')
          digest = OpenSSL::HMAC.digest(digVer, key, stringToSign)
          signature = Base64.encode64(digest)
          signature[-1] = ''
          signature
        end
      end
    end
  end
end
