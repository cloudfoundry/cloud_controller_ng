require 'fog/openstack/auth/token'
require 'fog/openstack/auth/name'

module Fog
  module OpenStack
    module Auth
      module Token
        class CredentialsError < RuntimeError; end

        class V2
          include Fog::OpenStack::Auth::Token
          attr_reader :tenant

          def credentials
            if @token
              identity = {'token' => {'id' => @token}}
            else
              raise CredentialsError, "#{self.class}: User name is required" if @user.name.nil?
              raise CredentialsError, "#{self.class}: User password is required" if @user.password.nil?
              identity = {'passwordCredentials' => user_credentials}
            end

            if @tenant.id
              identity['tenantId'] = @tenant.id.to_s
            elsif @tenant.name
              identity['tenantName'] = @tenant.name.to_s
            end

            {'auth' => identity}
          end

          def prefix_path(uri)
            if uri.path =~ /\/v2(\.0)*(\/)*.*$/
              ''
            else
              '/v2.0'
            end
          end

          def path
            '/tokens'
          end

          def user_credentials
            {
              'username' => @user.name.to_s,
              'password' => @user.password
            }
          end

          def set(response)
            @data = Fog::JSON.decode(response.body)
            @token   = @data['access']['token']['id']
            @expires = @data['access']['token']['expires']
            @tenant = @data['access']['token']['tenant']
            @user = @data['access']['user']
            catalog = @data['access']['serviceCatalog']
            @catalog = Fog::OpenStack::Auth::Catalog::V2.new(catalog) if catalog
          end

          def build_credentials(auth)
            if auth[:openstack_auth_token]
              @token = auth[:openstack_auth_token]
            else
              @user = Fog::OpenStack::Auth::User.new(auth[:openstack_userid], auth[:openstack_username])
              @user.password = auth[:openstack_api_key]
            end

            @tenant = Fog::OpenStack::Auth::Name.new(auth[:openstack_tenant_id], auth[:openstack_tenant])
            credentials
          end
        end
      end
    end
  end
end
