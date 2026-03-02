require 'spec_helper'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/routes_spec.rb for better test parallelization

RSpec.describe 'Routes Request' do
  include_context 'routes request spec'

  describe 'POST /v3/routes' do
    context 'when creating a route in a tcp domain' do
      let(:domain) { VCAP::CloudController::SharedDomain.make(router_group_guid: 'some-router-group', router_group_type: 'tcp') }

      before do
        token = { token_type: 'Bearer', access_token: 'my-favourite-access-token' }
        stub_request(:post, 'https://uaa.service.cf.internal/oauth/token').
          to_return(status: 200, body: token.to_json, headers: { 'Content-Type' => 'application/json' })
        stub_request(:get, 'http://localhost:3000/routing/v1/router_groups').
          to_return(status: 200, body: '[{"guid":"some-router-group","name":"Robby Router","type":"tcp","reservable_ports":"25555"}]', headers: {})
      end

      context 'and the route has a host' do
        let(:params) do
          {
            host: 'my-host',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        it 'returns a 422 and a helpful error message' do
          post '/v3/routes', params.to_json, admin_header
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message('Hosts are not supported for TCP routes.')
        end
      end

      context 'and the route has a path' do
        let(:params) do
          {
            path: '/cgi-bin',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        it 'returns a 422 and a helpful error message' do
          post '/v3/routes', params.to_json, admin_header
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message('Paths are not supported for TCP routes.')
        end
      end
    end

    context 'when creating a route in a scoped domain' do
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }

      describe 'when creating a route without a host' do
        let(:params) do
          {
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        let(:route_json) do
          {
            guid: UUID_REGEX,
            protocol: domain.protocols[0],
            host: '',
            path: '',
            port: nil,
            url: domain.name,
            created_at: iso8601,
            updated_at: iso8601,
            destinations: [],
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            },
            links: {
              self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
              space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{space.guid}} },
              destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
              domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}} }
            },
            metadata: {
              labels: {},
              annotations: {}
            },
            options: {}
          }
        end

        describe 'valid routes' do
          let(:api_call) { ->(user_headers) { post '/v3/routes', params.to_json, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              { code: 403 }.freeze
            )
            h['admin'] = {
              code: 201,
              response_object: route_json
            }
            h['space_developer'] = {
              code: 201,
              response_object: route_json
            }
            h['space_supporter'] = {
              code: 201,
              response_object: route_json
            }
            h
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end
      end

      describe 'when creating a route with a host' do
        let(:params) do
          {
            host: 'some-host',
            path: '/some-path',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            },
            metadata: {
              labels: { potato: 'yam' },
              annotations: { style: 'mashed' }
            },
            options: {}
          }
        end

        let(:route_json) do
          {
            guid: UUID_REGEX,
            protocol: domain.protocols[0],
            host: 'some-host',
            path: '/some-path',
            port: nil,
            url: "some-host.#{domain.name}/some-path",
            created_at: iso8601,
            updated_at: iso8601,
            destinations: [],
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            },
            links: {
              self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
              space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{space.guid}} },
              destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
              domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}} }
            },
            metadata: {
              labels: { potato: 'yam' },
              annotations: { style: 'mashed' }
            },
            options: {}
          }
        end

        describe 'valid routes' do
          it_behaves_like 'permissions for single object endpoint', ['admin'] do
            let(:api_call) { ->(user_headers) { post '/v3/routes', params.to_json, user_headers } }

            let(:expected_codes_and_responses) do
              h = Hash.new(
                { code: 403 }.freeze
              )
              h['admin'] = {
                code: 201,
                response_object: route_json
              }
              h['space_developer'] = {
                code: 201,
                response_object: route_json
              }
              h['space_supporter'] = {
                code: 201,
                response_object: route_json
              }
              h
            end

            let(:expected_event_hash) do
              {
                type: 'audit.route.create',
                actee: parsed_response['guid'],
                actee_type: 'route',
                actee_name: 'some-host',
                metadata: { request: params }.to_json,
                space_guid: space.guid,
                organization_guid: org.guid
              }
            end
          end
        end
      end

      describe 'when creating a route with a wildcard host' do
        let(:params) do
          {
            host: '*',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        let(:route_json) do
          {
            guid: UUID_REGEX,
            protocol: domain.protocols[0],
            host: '*',
            path: '',
            port: nil,
            url: "*.#{domain.name}",
            created_at: iso8601,
            updated_at: iso8601,
            destinations: [],
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            },
            links: {
              self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
              space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{space.guid}} },
              destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
              domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}} }
            },
            metadata: {
              labels: {},
              annotations: {}
            },
            options: {}
          }
        end

        describe 'valid routes' do
          let(:api_call) { ->(user_headers) { post '/v3/routes', params.to_json, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              { code: 403 }.freeze
            )
            h['admin'] = {
              code: 201,
              response_object: route_json
            }
            h['space_developer'] = {
              code: 201,
              response_object: route_json
            }
            h['space_supporter'] = {
              code: 201,
              response_object: route_json
            }
            h
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end
      end
    end

    context 'when creating a route in an unscoped domain' do
      let(:domain) { VCAP::CloudController::SharedDomain.make }

      describe 'when creating a route without a host' do
        let(:params) do
          {
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        it 'fails with a helpful message' do
          post '/v3/routes', params.to_json, admin_header
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message('Missing host. Routes in shared domains must have a host defined.')
        end
      end

      describe 'when creating a route with a host' do
        let(:params) do
          {
            host: 'some-host',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        let(:route_json) do
          {
            guid: UUID_REGEX,
            protocol: domain.protocols[0],
            host: 'some-host',
            path: '',
            port: nil,
            url: "some-host.#{domain.name}",
            created_at: iso8601,
            updated_at: iso8601,
            destinations: [],
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            },
            links: {
              self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
              space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{space.guid}} },
              destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
              domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}} }
            },
            metadata: {
              labels: {},
              annotations: {}
            },
            options: {}
          }
        end

        describe 'valid routes' do
          let(:api_call) { ->(user_headers) { post '/v3/routes', params.to_json, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              { code: 403 }.freeze
            )
            h['admin'] = {
              code: 201,
              response_object: route_json
            }
            h['space_developer'] = {
              code: 201,
              response_object: route_json
            }
            h['space_supporter'] = {
              code: 201,
              response_object: route_json
            }
            h
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end
      end

      describe 'when creating a route with a wildcard host' do
        let(:params) do
          {
            host: '*',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        let(:route_json) do
          {
            guid: UUID_REGEX,
            protocol: domain.protocols[0],
            host: '*',
            path: '',
            port: nil,
            url: "*.#{domain.name}",
            created_at: iso8601,
            updated_at: iso8601,
            destinations: [],
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            },
            links: {
              self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
              space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{space.guid}} },
              destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
              domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}} }
            },
            metadata: {
              labels: {},
              annotations: {}
            },
            options: {}
          }
        end

        describe 'valid routes' do
          let(:api_call) { ->(user_headers) { post '/v3/routes', params.to_json, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              { code: 403 }.freeze
            )
            h['admin'] = {
              code: 201,
              response_object: route_json
            }
            h['space_developer'] = {
              code: 422
            }
            h['space_supporter'] = {
              code: 422
            }
            h
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end
      end

      describe 'the domain supports tcp routes' do
        let(:router_group) { VCAP::CloudController::RoutingApi::RouterGroup.new({ 'type' => 'tcp', 'reservable_ports' => '123' }) }
        let(:domain) { VCAP::CloudController::SharedDomain.make(router_group_guid: 'some-router-group', name: 'my.domain') }
        let(:routing_api_client) { instance_double(VCAP::CloudController::RoutingApi::Client) }

        before do
          TestConfig.override(
            kubernetes: { host_url: nil },
            external_domain: 'api2.vcap.me',
            external_protocol: 'https'
          )
          allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
          allow(routing_api_client).to receive_messages(enabled?: true, router_group: router_group)
        end

        let(:params) do
          {
            port: 123,
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        let(:api_call) { ->(user_headers) { post '/v3/routes', params.to_json, user_headers } }

        let(:route_json) do
          {
            guid: UUID_REGEX,
            port: 123,
            host: '',
            path: '',
            protocol: 'tcp',
            url: "#{domain.name}:123",
            created_at: iso8601,
            updated_at: iso8601,
            destinations: [],
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            },
            links: {
              self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
              space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{space.guid}} },
              destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
              domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}} }
            },
            metadata: {
              labels: {},
              annotations: {}
            },
            options: {}
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            { code: 403 }.freeze
          )
          h['admin'] = {
            code: 201,
            response_object: route_json
          }
          h['space_developer'] = {
            code: 201,
            response_object: route_json
          }
          h['space_supporter'] = {
            code: 201,
            response_object: route_json
          }
          h
        end

        context 'and the user provides a valid port' do
          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

          context 'and a route with the domain and port already exist' do
            let!(:duplicate_route) { VCAP::CloudController::Route.make(host: '', space: space, domain: domain, port: 123) }

            it 'fails with a helpful error message' do
              post '/v3/routes', params.to_json, admin_headers
              expect(last_response).to have_status_code(422)
              expect(last_response).to have_error_message("Route already exists with port '123' for domain 'my.domain'.")
            end
          end

          context 'and the port is already in use for the router group' do
            let!(:other_domain) { VCAP::CloudController::SharedDomain.make(router_group_guid: 'some-router-group', name: 'my.domain2') }
            let!(:route_with_port) { VCAP::CloudController::Route.make(host: '', space: space, domain: other_domain, port: 123) }

            it 'fails with a helpful error message' do
              post '/v3/routes', params.to_json, admin_headers
              expect(last_response).to have_status_code(422)
              expect(last_response).to have_error_message("Port '123' is not available. Try a different port or use a different domain.")
            end
          end
        end

        context 'and the user does not provide a port' do
          let(:params) do
            {
              relationships: {
                space: {
                  data: { guid: space.guid }
                },
                domain: {
                  data: { guid: domain.guid }
                }
              }
            }
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

          context 'and randomly selected port is already in use' do
            let(:existing_route) { VCAP::CloudController::Route.make(host: '', space: space, domain: domain, port: 123) }

            let(:params) do
              {
                port: existing_route.port,
                relationships: {
                  space: {
                    data: { guid: space.guid }
                  },
                  domain: {
                    data: { guid: domain.guid }
                  }
                }
              }
            end

            it 'fails with a helpful error message' do
              post '/v3/routes', params.to_json, admin_headers
              expect(last_response).to have_status_code(422)
              expect(last_response).to have_error_message("Route already exists with port '123' for domain 'my.domain'.")
            end
          end
        end
      end
    end

    context 'when creating a route in a suspended org' do
      before do
        org.update(status: VCAP::CloudController::Organization::SUSPENDED)
      end

      let(:domain) { VCAP::CloudController::SharedDomain.make }

      let(:params) do
        {
          host: 'some-host',
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            }
          }
        }
      end

      let(:route_json) do
        {
          guid: UUID_REGEX,
          protocol: domain.protocols[0],
          host: 'some-host',
          path: '',
          port: nil,
          url: "some-host.#{domain.name}",
          created_at: iso8601,
          updated_at: iso8601,
          destinations: [],
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            }
          },
          metadata: {
            labels: {},
            annotations: {}
          },
          links: {
            self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
            space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{space.guid}} },
            destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
            domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}} }
          },
          options: {}
        }
      end

      describe 'valid routes' do
        let(:api_call) { ->(user_headers) { post '/v3/routes', params.to_json, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
          h['admin'] = {
            code: 201,
            response_object: route_json
          }
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when creating a route in an internal domain' do
      let(:domain) { VCAP::CloudController::SharedDomain.make(internal: true) }

      describe 'when creating a route with a wildcard host' do
        let(:params) do
          {
            host: '*',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        it 'fails with a helpful message' do
          post '/v3/routes', params.to_json, admin_header
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message('Wildcard hosts are not supported for internal domains.')
        end
      end

      describe 'when creating a route with a path' do
        let(:params) do
          {
            host: 'host',
            path: '/apath',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        it 'fails with a helpful message' do
          post '/v3/routes', params.to_json, admin_header
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message('Paths are not supported for internal domains.')
        end
      end

      describe 'when creating a route with a host' do
        let(:params) do
          {
            host: 'some-host',
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        let(:route_json) do
          {
            guid: UUID_REGEX,
            protocol: domain.protocols[0],
            host: 'some-host',
            path: '',
            port: nil,
            url: "some-host.#{domain.name}",
            created_at: iso8601,
            updated_at: iso8601,
            destinations: [],
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            },
            links: {
              self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
              space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{space.guid}} },
              destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
              domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}} }
            },
            metadata: {
              labels: {},
              annotations: {}
            },
            options: {}
          }
        end

        describe 'valid routes' do
          let(:api_call) { ->(user_headers) { post '/v3/routes', params.to_json, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              { code: 403 }.freeze
            )
            h['admin'] = {
              code: 201,
              response_object: route_json
            }
            h['space_developer'] = {
              code: 201,
              response_object: route_json
            }
            h['space_supporter'] = {
              code: 201,
              response_object: route_json
            }
            h
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end
      end
    end

    context 'when the domain has an owning org that is different from the space\'s parent org' do
      let(:other_org) { VCAP::CloudController::Organization.make }
      let(:inaccessible_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: other_org) }

      let(:params_with_inaccessible_domain) do
        {
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: inaccessible_domain.guid }
            }
          }
        }
      end

      it 'returns a 422 with a helpful error message' do
        post '/v3/routes', params_with_inaccessible_domain.to_json, admin_header
        expect(last_response).to have_status_code(422)
        expect(last_response).to have_error_message("Invalid domain. Domain '#{inaccessible_domain.name}' is not available in organization '#{org.name}'.")
      end
    end

    context 'when the host-less route has already been created for this domain' do
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
      let!(:existing_route) { VCAP::CloudController::Route.make(host: '', space: space, domain: domain) }

      let(:params_for_duplicate_route) do
        {
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            }
          }
        }
      end

      it 'returns a 422 with a helpful error message' do
        post '/v3/routes', params_for_duplicate_route.to_json, admin_header
        expect(last_response).to have_status_code(422)
        expect(last_response).to have_error_message("Route already exists for domain '#{domain.name}'.")
      end
    end

    context 'when there is already a route' do
      context 'with the host/domain/path combination' do
        let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
        let!(:existing_route) { VCAP::CloudController::Route.make(host: 'my-host', path: '/existing', space: space, domain: domain) }

        let(:params_for_duplicate_route) do
          {
            host: existing_route.host,
            path: existing_route.path,
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        it 'returns a 422 with a helpful error message' do
          post '/v3/routes', params_for_duplicate_route.to_json, admin_header
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message("Route already exists with host '#{existing_route.host}' and path '#{existing_route.path}' for domain '#{domain.name}'.")
        end
      end

      context 'with the host/domain combination' do
        let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
        let!(:existing_route) { VCAP::CloudController::Route.make(host: 'my-host', space: space, domain: domain) }

        let(:params_for_duplicate_route) do
          {
            host: existing_route.host,
            path: existing_route.path,
            relationships: {
              space: {
                data: { guid: space.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        it 'returns a 422 with a helpful error message' do
          post '/v3/routes', params_for_duplicate_route.to_json, admin_header
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message("Route already exists with host '#{existing_route.host}' for domain '#{domain.name}'.")
        end
      end
    end

    context 'when there is already a domain matching the host/domain combination' do
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
      let!(:existing_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization, name: "#{params[:host]}.#{domain.name}") }

      let(:params) do
        {
          host: 'some-host',
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            }
          }
        }
      end

      it 'returns a 422 with a helpful error message' do
        post '/v3/routes', params.to_json, admin_header
        expect(last_response).to have_status_code(422)
        expect(last_response).to have_error_message("Route conflicts with domain '#{existing_domain.name}'.")
      end
    end

    context 'when using a reserved system hostname with the system domain' do
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }

      let(:params) do
        {
          host: 'host',
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            }
          }
        }
      end

      before do
        VCAP::CloudController::Config.config.set(:system_domain, domain.name)
        VCAP::CloudController::Config.config.set(:system_hostnames, [params[:host]])
      end

      it 'returns a 422 with a helpful error message' do
        post '/v3/routes', params.to_json, admin_header
        expect(last_response).to have_status_code(422)
        expect(last_response).to have_error_message('Route conflicts with a reserved system route.')
      end
    end

    context 'when using a non-reserved hostname with the system domain' do
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
      let(:api_call) { ->(user_headers) { post '/v3/routes', params.to_json, user_headers } }

      let(:params) do
        {
          host: 'host',
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            }
          }
        }
      end

      let(:route_json) do
        {
          guid: UUID_REGEX,
          protocol: domain.protocols[0],
          host: params[:host],
          path: '',
          port: nil,
          url: "#{params[:host]}.#{domain.name}",
          created_at: iso8601,
          updated_at: iso8601,
          destinations: [],
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            }
          },
          metadata: {
            labels: {},
            annotations: {}
          },
          links: {
            self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}} },
            space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{space.guid}} },
            destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{UUID_REGEX}/destinations} },
            domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain.guid}} }
          },
          options: {}
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          { code: 403 }.freeze
        )
        h['admin'] = {
          code: 201,
          response_object: route_json
        }
        h['space_developer'] = {
          code: 201,
          response_object: route_json
        }
        h['space_supporter'] = {
          code: 201,
          response_object: route_json
        }
        h
      end

      before do
        VCAP::CloudController::Config.config.set(:system_domain, domain.name)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    describe 'quotas' do
      context 'when the space quota for routes is maxed out' do
        let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
        let!(:space_quota_definition) { VCAP::CloudController::SpaceQuotaDefinition.make(total_routes: 0, organization: org) }
        let!(:space_with_quota) { VCAP::CloudController::Space.make(space_quota_definition: space_quota_definition, organization: org) }

        let(:params_for_space_with_quota) do
          {
            relationships: {
              space: {
                data: { guid: space_with_quota.guid }
              },
              domain: {
                data: { guid: domain.guid }
              }
            }
          }
        end

        it 'returns a 422 with a helpful error message' do
          post '/v3/routes', params_for_space_with_quota.to_json, admin_header
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message("Routes quota exceeded for space '#{space_with_quota.name}'.")
        end
      end

      context 'when the org quota for routes is maxed out' do
        let!(:org_quota_definition) { VCAP::CloudController::QuotaDefinition.make(total_routes: 0, total_reserved_route_ports: 0) }
        let!(:org_with_quota) { VCAP::CloudController::Organization.make(quota_definition: org_quota_definition) }
        let!(:space_in_org_with_quota) do
          VCAP::CloudController::Space.make(organization: org_with_quota)
        end
        let(:domain_in_org_with_quota) { VCAP::CloudController::Domain.make(owning_organization: org_with_quota) }

        let(:params_for_org_with_quota) do
          {
            relationships: {
              space: {
                data: { guid: space_in_org_with_quota.guid }
              },
              domain: {
                data: { guid: domain_in_org_with_quota.guid }
              }
            }
          }
        end

        it 'returns a 422 with a helpful error message' do
          post '/v3/routes', params_for_org_with_quota.to_json, admin_header
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message("Routes quota exceeded for organization '#{org_with_quota.name}'.")
        end
      end
    end

    context 'when the feature flag is disabled' do
      let(:headers) { set_user_with_header_as_role(user: user, role: 'space_developer', org: org, space: space) }
      let!(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'route_creation', enabled: false, error_message: 'my name is bob') }
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
      let(:params) do
        {
          host: 'some-host',
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            }
          }
        }
      end

      context 'when the user is not an admin' do
        it 'returns a 403' do
          post '/v3/routes', params.to_json, headers

          expect(last_response).to have_status_code(403)
          expect(parsed_response['errors'][0]['detail']).to eq('Feature Disabled: my name is bob')
        end
      end

      context 'when the user is an admin' do
        let(:headers) { set_user_with_header_as_role(role: 'admin') }

        it 'allows creation' do
          post '/v3/routes', params.to_json, headers

          expect(last_response).to have_status_code(201)
        end
      end
    end

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        post '/v3/routes', {}.to_json, base_json_headers
        expect(last_response).to have_status_code(401)
      end
    end

    context 'when the user does not have the required scopes' do
      let(:user_header) { headers_for(user, scopes: ['cloud_controller.read']) }

      it 'returns a 403' do
        post '/v3/routes', {}.to_json, user_header
        expect(last_response).to have_status_code(403)
      end
    end

    context 'when the space does not exist' do
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }

      let(:params_with_invalid_space) do
        {
          relationships: {
            space: {
              data: { guid: 'invalid-space' }
            },
            domain: {
              data: { guid: domain.guid }
            }
          }
        }
      end

      it 'returns a 422 with a helpful error message' do
        post '/v3/routes', params_with_invalid_space.to_json, admin_header
        expect(last_response).to have_status_code(422)
        expect(last_response).to have_error_message('Invalid space. Ensure that the space exists and you have access to it.')
      end
    end

    context 'when the domain does not exist' do
      let(:params_with_invalid_domain) do
        {
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: 'invalid-domain' }
            }
          }
        }
      end

      it 'returns a 422 with a helpful error message' do
        post '/v3/routes', params_with_invalid_domain.to_json, admin_header
        expect(last_response).to have_status_code(422)
        expect(last_response).to have_error_message('Invalid domain. Ensure that the domain exists and you have access to it.')
      end
    end

    context 'when communicating with the routing API' do
      let(:routing_api_client) { instance_double(VCAP::CloudController::RoutingApi::Client) }
      let(:router_group) { VCAP::CloudController::RoutingApi::RouterGroup.new({ 'type' => 'tcp', 'guid' => 'some-guid' }) }
      let(:headers) { set_user_with_header_as_role(role: 'admin') }
      let(:domain_tcp) { VCAP::CloudController::SharedDomain.make(router_group_guid: router_group.guid, name: 'my.domain') }
      let(:params) do
        {
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain_tcp.guid }
            }
          }
        }
      end

      before do
        allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
      end

      context 'when UAA is unavailable' do
        before do
          allow(routing_api_client).to receive(:router_group).and_raise VCAP::CloudController::RoutingApi::UaaUnavailable
        end

        it 'returns a 503 with a helpful error message' do
          post '/v3/routes', params.to_json, headers

          expect(last_response).to have_status_code(503)
          expect(parsed_response['errors'][0]['detail']).to eq 'Communicating with the Routing API failed because UAA is currently unavailable. Please try again later.'
        end
      end

      context 'when the routing API is unavailable' do
        before do
          allow(routing_api_client).to receive(:enabled?).and_return true
          allow(routing_api_client).to receive(:router_group).and_raise VCAP::CloudController::RoutingApi::RoutingApiUnavailable
        end

        it 'returns a 503 with a helpful error message' do
          post '/v3/routes', params.to_json, headers

          expect(last_response).to have_status_code(503)
          expect(parsed_response['errors'][0]['detail']).to eq 'The Routing API is currently unavailable. Please try again later.'
        end
      end

      context 'when the routing API is disabled' do
        before do
          allow(routing_api_client).to receive(:enabled?).and_return false
          allow(routing_api_client).to receive(:router_group).and_raise VCAP::CloudController::RoutingApi::RoutingApiDisabled
        end

        it 'returns a 503 with a helpful error message' do
          post '/v3/routes', params.to_json, headers

          expect(last_response).to have_status_code(503)
          expect(parsed_response['errors'][0]['detail']).to eq 'The Routing API is disabled.'
        end
      end

      context 'when the router group is unavailable' do
        let(:domain_tcp) { VCAP::CloudController::SharedDomain.make(router_group_guid: 'not a guid', name: 'my.domain') }

        before do
          allow(routing_api_client).to receive_messages(enabled?: true, router_group: nil)
        end

        it 'returns a 503 with a helpful error message' do
          post '/v3/routes', params.to_json, headers

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors'][0]['detail']).to eq 'Route could not be created because the specified domain does not have a valid router group.'
        end
      end
    end
  end
end
