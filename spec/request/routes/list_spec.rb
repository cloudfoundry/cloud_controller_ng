require 'spec_helper'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/routes_spec.rb for better test parallelization

RSpec.describe 'Routes Request' do
  include_context 'routes request spec'

  describe 'GET /v3/routes' do
    let(:other_space) { VCAP::CloudController::Space.make(name: 'b-space') }
    let(:app_model) { VCAP::CloudController::AppModel.make(space:) }
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
    let!(:route_in_org) do
      VCAP::CloudController::Route.make(space: space, domain: domain, host: 'host-1', path: '/path1', guid: 'route-in-org-guid')
    end
    let!(:route_in_other_org) do
      VCAP::CloudController::Route.make(space: other_space, host: 'host-2', path: '/path2', guid: 'route-in-other-org-guid')
    end
    let!(:route_in_org_dest_web) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route_in_org, process_type: 'web') }
    let!(:route_in_org_dest_worker) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route_in_org, process_type: 'worker') }
    let(:api_call) { ->(user_headers) { get '/v3/routes', nil, user_headers } }
    let(:route_in_org_json) do
      {
        guid: route_in_org.guid,
        protocol: route_in_org.domain.protocols[0],
        host: route_in_org.host,
        path: route_in_org.path,
        port: nil,
        url: "#{route_in_org.host}.#{route_in_org.domain.name}#{route_in_org.path}",
        created_at: iso8601,
        updated_at: iso8601,
        destinations: contain_exactly({
                                        guid: route_in_org_dest_web.guid,
                                        app: {
                                          guid: app_model.guid,
                                          process: {
                                            type: route_in_org_dest_web.process_type
                                          }
                                        },
                                        weight: route_in_org_dest_web.weight,
                                        port: route_in_org_dest_web.presented_port,
                                        protocol: 'http1',
                                        created_at: iso8601,
                                        updated_at: iso8601
                                      }, {
                                        guid: route_in_org_dest_worker.guid,
                                        app: {
                                          guid: app_model.guid,
                                          process: {
                                            type: route_in_org_dest_worker.process_type
                                          }
                                        },
                                        weight: route_in_org_dest_worker.weight,
                                        port: route_in_org_dest_worker.presented_port,
                                        protocol: 'http1',
                                        created_at: iso8601,
                                        updated_at: iso8601
                                      }),
        relationships: {
          space: {
            data: { guid: route_in_org.space.guid }
          },
          domain: {
            data: { guid: route_in_org.domain.guid }
          }
        },
        metadata: {
          labels: {},
          annotations: {}
        },
        options: {},
        links: {
          self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{route_in_org.guid}} },
          space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{route_in_org.space.guid}} },
          destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{route_in_org.guid}/destinations} },
          domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{route_in_org.domain.guid}} }
        }
      }
    end

    let(:route_in_other_org_json) do
      {
        guid: route_in_other_org.guid,
        protocol: route_in_other_org.domain.protocols[0],
        host: route_in_other_org.host,
        path: route_in_other_org.path,
        port: nil,
        url: "#{route_in_other_org.host}.#{route_in_other_org.domain.name}#{route_in_other_org.path}",
        created_at: iso8601,
        updated_at: iso8601,
        destinations: [],
        relationships: {
          space: {
            data: { guid: route_in_other_org.space.guid }
          },
          domain: {
            data: { guid: route_in_other_org.domain.guid }
          }
        },
        metadata: {
          labels: {},
          annotations: {}
        },
        options: {},
        links: {
          self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{route_in_other_org.guid}} },
          space: { href: %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{route_in_other_org.space.guid}} },
          destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{route_in_other_org.guid}/destinations} },
          domain: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{route_in_other_org.domain.guid}} }
        }
      }
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::Route }
      let(:api_call) do
        ->(headers, filters) { get "/v3/routes?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end

    describe 'query list parameters' do
      it_behaves_like 'list query endpoint' do
        let(:request) { 'v3/routes' }
        let(:message) { VCAP::CloudController::RoutesListMessage }
        let(:user_header) { admin_header }

        let(:params) do
          {
            page: '2',
            per_page: '10',
            order_by: 'updated_at',
            space_guids: %w[foo bar],
            service_instance_guids: %w[baz qux],
            organization_guids: %w[foo bar],
            domain_guids: %w[foo bar],
            app_guids: %w[foo bar],
            guids: %w[foo bar],
            paths: %w[foo bar],
            hosts: 'foo',
            ports: 636,
            include: 'domain',
            label_selector: 'foo,bar',
            created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
            updated_ats: { gt: Time.now.utc.iso8601 }
          }
        end
      end
    end

    context 'when the user is a member in the routes org' do
      let(:expected_codes_and_responses) do
        h = Hash.new(
          { code: 200,
            response_objects: [route_in_org_json] }.freeze
        )

        h['admin'] = { code: 200, response_objects: [route_in_org_json, route_in_other_org_json] }
        h['admin_read_only'] = { code: 200, response_objects: [route_in_org_json, route_in_other_org_json] }
        h['global_auditor'] = { code: 200, response_objects: [route_in_org_json, route_in_other_org_json] }

        h['org_billing_manager'] = { code: 200, response_objects: [] }
        h['no_role'] = { code: 200, response_objects: [] }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    describe 'includes' do
      context 'when including domains' do
        let(:domain1) { VCAP::CloudController::SharedDomain.make(name: 'first-domain.example.com') }
        let(:domain1_json) do
          {
            guid: domain1.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: domain1.name,
            internal: false,
            router_group: nil,
            supported_protocols: ['http'],
            metadata: {
              labels: {},
              annotations: {}
            },
            relationships: {
              organization: {
                data: nil
              },
              shared_organizations: {
                data: []
              }
            },
            links: {
              self: { href: "#{link_prefix}/v3/domains/#{domain1.guid}" },
              route_reservations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain1.guid}/route_reservations} }
            }
          }
        end

        let(:domain2) { VCAP::CloudController::SharedDomain.make(name: 'second-domain.example.com') }
        let(:domain2_json) do
          {
            guid: domain2.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: domain2.name,
            internal: false,
            router_group: nil,
            supported_protocols: ['http'],
            metadata: {
              labels: {},
              annotations: {}
            },
            relationships: {
              organization: {
                data: nil
              },
              shared_organizations: {
                data: []
              }
            },
            links: {
              self: { href: "#{link_prefix}/v3/domains/#{domain1.guid}" },
              route_reservations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain1.guid}/route_reservations} }
            }
          }
        end

        let(:domain2) { VCAP::CloudController::SharedDomain.make(name: 'second-domain.example.com') }
        let(:domain2_json) do
          {
            guid: domain2.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: domain2.name,
            internal: false,
            router_group: nil,
            supported_protocols: ['http'],
            metadata: {
              labels: {},
              annotations: {}
            },
            relationships: {
              organization: {
                data: nil
              },
              shared_organizations: {
                data: []
              }
            },
            links: {
              self: { href: "#{link_prefix}/v3/domains/#{domain2.guid}" },
              route_reservations: { href: %r{#{Regexp.escape(link_prefix)}/v3/domains/#{domain2.guid}/route_reservations} }
            }
          }
        end

        let!(:route1_domain1) do
          VCAP::CloudController::Route.make(space: space, host: 'route1', domain: domain1, path: '/path1', guid: 'route1-guid')
        end
        let(:route1_domain1_json) do
          {
            guid: route1_domain1.guid,
            protocol: route1_domain1.domain.protocols[0],
            created_at: iso8601,
            updated_at: iso8601,
            host: route1_domain1.host,
            path: route1_domain1.path,
            port: nil,
            url: "#{route1_domain1.host}.#{domain1.name}#{route1_domain1.path}",
            destinations: [],
            metadata: {
              labels: {},
              annotations: {}
            },
            relationships: {
              space: {
                data: {
                  guid: space.guid
                }
              },
              domain: {
                data: {
                  guid: domain1.guid
                }
              }
            },
            options: {},
            links: {
              self: { href: "http://api2.vcap.me/v3/routes/#{route1_domain1.guid}" },
              space: { href: "http://api2.vcap.me/v3/spaces/#{space.guid}" },
              destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{route1_domain1.guid}/destinations} },
              domain: { href: "http://api2.vcap.me/v3/domains/#{domain1.guid}" }
            }
          }
        end

        let!(:route_in_org) do
          VCAP::CloudController::Route.make(space: space, domain: domain1, host: 'host-1', path: '/path1', guid: 'route-in-org-guid')
        end
        let!(:route_in_other_org) do
          VCAP::CloudController::Route.make(space: other_space, domain: domain2, host: 'host-2', path: '/path2', guid: 'route-in-other-org-guid')
        end

        it 'includes the unique domains for the routes' do
          get '/v3/routes?include=domain', nil, admin_header
          expect(last_response).to have_status_code(200)
          expect({
                   resources: parsed_response['resources'],
                   included: parsed_response['included']
                 }).to match_json_response({
                                             resources: [route_in_org_json, route_in_other_org_json, route1_domain1_json],
                                             included: { 'domains' => [domain1_json, domain2_json] }
                                           })
        end
      end

      context 'when including spaces and orgs' do
        it 'includes the unique spaces and organizations for the routes' do
          get '/v3/routes?include=space,space.organization', nil, admin_header
          expect(last_response).to have_status_code(200)
          expect({
                   resources: parsed_response['resources'],
                   included: parsed_response['included']
                 }).to match_json_response({
                                             resources: [route_in_org_json, route_in_other_org_json],
                                             included: {
                                               'spaces' => [
                                                 space_json_generator.call(space),
                                                 space_json_generator.call(other_space)
                                               ],
                                               'organizations' => [
                                                 org_json_generator.call(org),
                                                 org_json_generator.call(other_space.organization)
                                               ]
                                             }
                                           })
        end
      end

      context 'when including spaces' do
        it 'eagerly loads spaces to efficiently access space_guid' do
          expect(VCAP::CloudController::IncludeSpaceDecorator).to receive(:decorate) do |_, resources|
            expect(resources).not_to be_empty
            resources.each { |r| expect(r.associations).to include(:space) }
          end

          get '/v3/routes?include=space', nil, admin_header
          expect(last_response).to have_status_code(200)
        end
      end

      context 'when including orgs' do
        it 'eagerly loads spaces to efficiently access space.organization_id' do
          expect(VCAP::CloudController::IncludeOrganizationDecorator).to receive(:decorate) do |_, resources|
            expect(resources).not_to be_empty
            resources.each { |r| expect(r.associations).to include(:space) }
          end

          get '/v3/routes?include=space.organization', nil, admin_header
          expect(last_response).to have_status_code(200)
        end
      end
    end

    describe 'filters' do
      let!(:route_without_host_and_with_path) do
        VCAP::CloudController::Route.make(space: space, host: '', domain: domain, path: '/path1', guid: 'route-without-host')
      end
      let!(:route_without_host_and_with_path2) do
        VCAP::CloudController::Route.make(space: space, host: '', domain: domain, path: '/path2', guid: 'route-without-host2')
      end
      let(:route_without_host_and_with_path_json) do
        {
          guid: 'route-without-host',
          protocol: domain.protocols[0],
          created_at: iso8601,
          updated_at: iso8601,
          destinations: [],
          host: '',
          path: '/path1',
          port: nil,
          url: "#{domain.name}/path1",
          metadata: {
            labels: {},
            annotations: {}
          },
          relationships: {
            space: {
              data: {
                guid: space.guid
              }
            },
            domain: {
              data: {
                guid: domain.guid
              }
            }
          },
          options: {},
          links: {
            self: { href: 'http://api2.vcap.me/v3/routes/route-without-host' },
            space: { href: "http://api2.vcap.me/v3/spaces/#{space.guid}" },
            destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/route-without-host/destinations} },
            domain: { href: "http://api2.vcap.me/v3/domains/#{domain.guid}" }
          }
        }
      end
      let(:route_without_host_and_with_path2_json) do
        {
          guid: 'route-without-host2',
          protocol: domain.protocols[0],
          created_at: iso8601,
          updated_at: iso8601,
          destinations: [],
          host: '',
          path: '/path2',
          port: nil,
          url: "#{domain.name}/path2",
          metadata: {
            labels: {},
            annotations: {}
          },
          relationships: {
            space: {
              data: {
                guid: space.guid
              }
            },
            domain: {
              data: {
                guid: domain.guid
              }
            }
          },
          options: {},
          links: {
            self: { href: 'http://api2.vcap.me/v3/routes/route-without-host2' },
            space: { href: "http://api2.vcap.me/v3/spaces/#{space.guid}" },
            destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/route-without-host2/destinations} },
            domain: { href: "http://api2.vcap.me/v3/domains/#{domain.guid}" }
          }
        }
      end
      let!(:route_without_path_and_with_host) do
        VCAP::CloudController::Route.make(space: space, host: 'host-1', domain: domain, path: '', guid: 'route-without-path')
      end
      let(:route_without_path_and_with_host_json) do
        {
          guid: 'route-without-path',
          protocol: domain.protocols[0],
          created_at: iso8601,
          updated_at: iso8601,
          destinations: [],
          host: 'host-1',
          path: '',
          port: nil,
          url: "host-1.#{domain.name}",
          metadata: {
            labels: {},
            annotations: {}
          },
          relationships: {
            space: {
              data: {
                guid: space.guid
              }
            },
            domain: {
              data: {
                guid: domain.guid
              }
            }
          },
          options: {},
          links: {
            self: { href: 'http://api2.vcap.me/v3/routes/route-without-path' },
            space: { href: "http://api2.vcap.me/v3/spaces/#{space.guid}" },
            destinations: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/route-without-path/destinations} },
            domain: { href: "http://api2.vcap.me/v3/domains/#{domain.guid}" }
          }
        }
      end

      context 'hosts filter' do
        it 'returns routes filtered by host' do
          get '/v3/routes?hosts=host-1', nil, admin_header
          expect(last_response).to have_status_code(200)
          expect({
                   resources: parsed_response['resources']
                 }).to match_json_response({
                                             resources: [route_in_org_json, route_without_path_and_with_host_json]
                                           })
        end

        it 'returns route with no host if one exists when filtering by empty host' do
          get '/v3/routes?hosts=', nil, admin_header
          expect(last_response).to have_status_code(200)
          expect({
                   resources: parsed_response['resources']
                 }).to match_json_response({
                                             resources: [route_without_host_and_with_path_json, route_without_host_and_with_path2_json]
                                           })
        end
      end

      context 'paths filter' do
        it 'returns routes filtered by path' do
          get '/v3/routes?paths=%2Fpath1', nil, admin_header
          expect(last_response).to have_status_code(200)
          expect({
                   resources: parsed_response['resources']
                 }).to match_json_response({
                                             resources: [route_in_org_json, route_without_host_and_with_path_json]
                                           })
        end

        it 'returns route with no path when filtering by empty path' do
          get '/v3/routes?paths=', nil, admin_header
          expect(last_response).to have_status_code(200)
          expect({
                   resources: parsed_response['resources']
                 }).to match_json_response({
                                             resources: [route_without_path_and_with_host_json]
                                           })
        end
      end

      context 'hosts and paths filter' do
        it 'returns routes with no host and the provided path when host is empty' do
          get '/v3/routes?paths=%2Fpath1&hosts=', nil, admin_header
          expect(last_response).to have_status_code(200)
          expect({
                   resources: parsed_response['resources']
                 }).to match_json_response({
                                             resources: [route_without_host_and_with_path_json]
                                           })
        end
      end

      context 'organization_guids filter' do
        it 'returns routes filtered by organization_guid' do
          get "/v3/routes?organization_guids=#{other_space.organization.guid}", nil, admin_header
          expect(last_response).to have_status_code(200)
          expect({
                   resources: parsed_response['resources']
                 }).to match_json_response({
                                             resources: [route_in_other_org_json]
                                           })
        end
      end

      context 'space_guids filter' do
        it 'returns routes filtered by space_guid' do
          get "/v3/routes?space_guids=#{other_space.guid}", nil, admin_header
          expect(last_response).to have_status_code(200)
          expect({
                   resources: parsed_response['resources']
                 }).to match_json_response({
                                             resources: [route_in_other_org_json]
                                           })
        end
      end

      context 'domain_guids filter' do
        it 'returns routes filtered by domain_guid' do
          get "/v3/routes?domain_guids=#{route_in_other_org.domain.guid}", nil, admin_header
          expect(last_response).to have_status_code(200)
          expect({
                   resources: parsed_response['resources']
                 }).to match_json_response({
                                             resources: [route_in_other_org_json]
                                           })
        end
      end

      context 'app_guids filter' do
        it 'returns routes filtered by app_guid' do
          get "/v3/routes?app_guids=#{app_model.guid}", nil, admin_header
          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'].size).to eq(1)
          expect(parsed_response['resources'].first['destinations'].size).to eq(2)
          expect(
            parsed_response['resources'].first['destinations'].map { |destination| destination['app']['guid'] }.uniq
          ).to eq([app_model.guid])
        end
      end

      context 'ports filter' do
        # Don't even think of converting the following hash to symbols ('type' => 'tcp' NOT type: 'tcp'), and you need to set the GUID
        let(:router_group) { VCAP::CloudController::RoutingApi::RouterGroup.new({ 'type' => 'tcp', 'reservable_ports' => '7777,8888,9999', 'guid' => 'some-guid' }) }
        let(:routing_api_client) { instance_double(VCAP::CloudController::RoutingApi::Client) }

        before do
          allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
          allow(routing_api_client).to receive_messages(enabled?: true, router_group: router_group)
        end

        context 'when there are multiple TCP routes with different ports' do
          # The following `let`s depend on the above `before do`
          let(:domain_tcp) { VCAP::CloudController::SharedDomain.make(router_group_guid: router_group.guid, name: 'my.domain') }
          let!(:route_with_ports_0) do
            VCAP::CloudController::Route.make(host: '', space: space, domain: domain_tcp, guid: 'route-with-port-0', port: 7777)
          end
          let!(:route_with_ports_1) do
            VCAP::CloudController::Route.make(host: '', space: space, domain: domain_tcp, guid: 'route-with-port-1', port: 8888)
          end
          let!(:route_with_ports_2) do
            VCAP::CloudController::Route.make(host: '', space: space, domain: domain_tcp, guid: 'route-with-port-2', port: 9999)
          end

          it 'returns routes filtered by ports' do
            get '/v3/routes?ports=7777,8888', nil, admin_header
            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources'].size).to eq(2)
            expect(parsed_response['resources'].pluck('port')).to contain_exactly(route_with_ports_0.port, route_with_ports_1.port)
          end
        end
      end

      context 'service instance guids filter' do
        let(:service_instance_one) do
          VCAP::CloudController::ManagedServiceInstance.make(:routing, space: space, name: 'si-name-1')
        end
        let(:service_instance_two) do
          VCAP::CloudController::ManagedServiceInstance.make(:routing, space: space, name: 'si-name-2')
        end

        let!(:route_with_service_instance_one) do
          VCAP::CloudController::Route.make(space: space, host: 'host-with-service-instance-one', domain: domain, path: '/path1', guid: 'route-with-service-instance-one')
        end
        let!(:route_with_service_instance_two) do
          VCAP::CloudController::Route.make(space: space, host: 'host-with-service-instance-two', domain: domain, path: '/path2', guid: 'route-with-service-instance-two')
        end

        let!(:route_mapping_one) { VCAP::CloudController::RouteBinding.make(route: route_with_service_instance_one, service_instance: service_instance_one) }
        let!(:route_mapping_two) { VCAP::CloudController::RouteBinding.make(route: route_with_service_instance_two, service_instance: service_instance_two) }

        it 'returns routes filtered by service instance guid' do
          get "/v3/routes?service_instance_guids=#{service_instance_one.guid},#{service_instance_two.guid}", nil, admin_header
          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'].size).to eq(2)
          expect(parsed_response['resources'].pluck('guid')).to contain_exactly('route-with-service-instance-one', 'route-with-service-instance-two')
        end
      end
    end

    describe 'labels' do
      let!(:domain1) { VCAP::CloudController::PrivateDomain.make(name: 'dom1.com', owning_organization: org) }
      let!(:route1) { VCAP::CloudController::Route.make(space: space, domain: domain1, host: 'hall', path: '/oates', guid: 'guid-1') }
      let!(:route1_label) { VCAP::CloudController::RouteLabelModel.make(resource_guid: route1.guid, key_name: 'animal', value: 'dog') }

      let!(:domain2) { VCAP::CloudController::PrivateDomain.make(name: 'dom2.com', owning_organization: org) }
      let!(:route2) { VCAP::CloudController::Route.make(space: space, domain: domain2, guid: 'guid-2') }
      let!(:route2_label) { VCAP::CloudController::RouteLabelModel.make(resource_guid: route2.guid, key_name: 'animal', value: 'cow') }
      let!(:route2__exclusive_label) { VCAP::CloudController::RouteLabelModel.make(resource_guid: route2.guid, key_name: 'santa', value: 'claus') }

      describe 'label_selectors' do
        it 'returns a 200 and the filtered routes for "in" label selector' do
          get '/v3/routes?label_selector=animal in (dog)', nil, admin_header

          expect(last_response).to have_status_code(200), last_response.body
          parsed_response = Oj.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered routes for "in" label selector with space guids' do
          get "/v3/routes?label_selector=animal in (dog)&space_guids=#{space.guid}", nil, admin_header

          expect(last_response).to have_status_code(200)
          parsed_response = Oj.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&page=1&per_page=50&space_guids=#{space.guid}" },
            'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&page=1&per_page=50&space_guids=#{space.guid}" },
            'next' => nil,
            'previous' => nil
          }

          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered routes for "in" label selector with org filters' do
          get "/v3/routes?label_selector=animal in (dog)&organization_guids=#{org.guid}", nil, admin_header

          expect(last_response).to have_status_code(200), last_response.body
          parsed_response = Oj.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&organization_guids=#{org.guid}&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&organization_guids=#{org.guid}&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered routes for "in" label selector with domain filters' do
          get "/v3/routes?label_selector=animal in (dog)&domain_guids=#{domain1.guid}", nil, admin_header

          expect(last_response).to have_status_code(200), last_response.body
          parsed_response = Oj.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/routes?domain_guids=#{domain1.guid}&label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/routes?domain_guids=#{domain1.guid}&label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered routes for "in" label selector with host filters' do
          get '/v3/routes?label_selector=animal in (dog)&hosts=hall', nil, admin_header

          expect(last_response).to have_status_code(200), last_response.body
          parsed_response = Oj.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/routes?hosts=hall&label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/routes?hosts=hall&label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered routes for "in" label selector with path filters' do
          get '/v3/routes?label_selector=animal in (dog)&paths=/oates', nil, admin_header

          expect(last_response).to have_status_code(200)
          parsed_response = Oj.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&page=1&paths=%2Foates&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&page=1&paths=%2Foates&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end
      end

      it 'returns a 200 and the filtered routes for "notin" label selector' do
        get '/v3/routes?label_selector=animal notin (dog)', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 3,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+notin+%28dog%29&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+notin+%28dog%29&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route2.guid, route_in_org.guid, route_in_other_org.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered routes for "=" label selector' do
        get '/v3/routes?label_selector=animal=dog', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%3Ddog&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%3Ddog&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered domains for "==" label selector' do
        get '/v3/routes?label_selector=animal==dog', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%3D%3Ddog&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%3D%3Ddog&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered routes for "!=" label selector' do
        get '/v3/routes?label_selector=animal!=dog', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 3,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%21%3Ddog&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%21%3Ddog&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route2.guid, route_in_org.guid, route_in_other_org.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered routes for "=" label selector' do
        get '/v3/routes?label_selector=animal=cow,santa=claus', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%3Dcow%2Csanta%3Dclaus&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%3Dcow%2Csanta%3Dclaus&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered routes for existence label selector' do
        get '/v3/routes?label_selector=santa', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=santa&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=santa&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered routes for non-existence label selector' do
        get '/v3/routes?label_selector=!santa', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 3,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=%21santa&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=%21santa&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(route1.guid, route_in_org.guid, route_in_other_org.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end

    describe 'eager loading' do
      it 'eager loads associated resources that the presenter specifies' do
        expect(VCAP::CloudController::RouteFetcher).to receive(:fetch).with(
          anything,
          hash_including(eager_loaded_associations: %i[domain space route_mappings labels annotations])
        ).and_call_original

        get '/v3/routes', nil, admin_header
        expect(last_response).to have_status_code(200)
      end
    end

    context 'when the request is invalid' do
      it 'returns 400 with a meaningful error' do
        get '/v3/routes?page=potato', nil, admin_header
        expect(last_response).to have_status_code(400)
        expect(last_response).to have_error_message('The query parameter is invalid: Page must be a positive integer')
      end
    end

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get '/v3/routes', nil, base_json_headers
        expect(last_response).to have_status_code(401)
      end
    end
  end
end
