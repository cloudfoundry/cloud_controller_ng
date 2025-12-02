require 'fog/openstack/auth/token'
require 'fog/openstack/auth/name'

module Fog
  module OpenStack
    module Auth
      module Token
        class V3
          include Fog::OpenStack::Auth::Token
          attr_reader :domain, :project

          # Default Domain ID
          DOMAIN_ID = 'default'.freeze

          def credentials
            identity = if @token
                         {
                           'methods' => ['token'],
                           'token'   => {'id' => @token}
                         }
                       elsif @application_credential
                         {
                           'methods' => ['application_credential'],
                           'application_credential' => @application_credential
                         }
                       else
                         {
                           'methods'  => ['password'],
                           'password' => @user.identity
                         }
                       end

            if scope
              {
                'auth' => {
                  'identity' => identity,
                  'scope'    => scope
                }
              }
            else
              {'auth' => {'identity' => identity}}
            end
          end

          def prefix_path(uri)
            if uri.path =~ /\/v3(\/)*.*$/
              ''
            else
              '/v3'
            end
          end

          def path
            '/auth/tokens'
          end

          def scope
            return nil if @application_credential
            return @project.identity if @project
            return @domain.identity if @domain
          end

          def set(response)
            @data = Fog::JSON.decode(response.body)
            @token = response.headers['x-subject-token']
            @expires = @data['token']['expires_at']
            @tenant = @data['token']['project']
            @user = @data['token']['user']
            catalog = @data['token']['catalog']
            if catalog
              @catalog = Fog::OpenStack::Auth::Catalog::V3.new(catalog)
            end
          end

          def build_credentials(auth)
            if auth[:openstack_project_id] || auth[:openstack_project_name]
              # project scoped
              @project = Fog::OpenStack::Auth::ProjectScope.new(
                auth[:openstack_project_id],
                auth[:openstack_project_name]
              )
              @project.domain = if auth[:openstack_project_domain_id] || auth[:openstack_project_domain_name]
                                  Fog::OpenStack::Auth::Name.new(
                                    auth[:openstack_project_domain_id],
                                    auth[:openstack_project_domain_name]
                                  )
                                elsif auth[:openstack_domain_id] || auth[:openstack_domain_name]
                                  Fog::OpenStack::Auth::Name.new(
                                    auth[:openstack_domain_id],
                                    auth[:openstack_domain_name]
                                  )
                                else
                                  Fog::OpenStack::Auth::Name.new(DOMAIN_ID, nil)
                                end
            elsif auth[:openstack_domain_id] || auth[:openstack_domain_name]
              # domain scoped
              @domain = Fog::OpenStack::Auth::DomainScope.new(
                auth[:openstack_domain_id],
                auth[:openstack_domain_name]
              )
            end

            if auth[:openstack_auth_token]
              @token = auth[:openstack_auth_token]
            elsif auth[:openstack_application_credential_id] and auth[:openstack_application_credential_secret]
              @application_credential = {
                :id => auth[:openstack_application_credential_id],
                :secret => auth[:openstack_application_credential_secret],
              }
            else
              @user = Fog::OpenStack::Auth::User.new(auth[:openstack_userid], auth[:openstack_username])
              @user.password = auth[:openstack_api_key]

              @user.domain = if auth[:openstack_user_domain_id] || auth[:openstack_user_domain_name]
                               Fog::OpenStack::Auth::Name.new(
                                 auth[:openstack_user_domain_id],
                                 auth[:openstack_user_domain_name]
                               )
                             elsif auth[:openstack_domain_id] || auth[:openstack_domain_name]
                               Fog::OpenStack::Auth::Name.new(
                                 auth[:openstack_domain_id],
                                 auth[:openstack_domain_name]
                               )
                             else
                               Fog::OpenStack::Auth::Name.new(DOMAIN_ID, nil)
                             end
            end

            credentials
          end
        end
      end
    end
  end
end
