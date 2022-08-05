require 'spec_helper'
require 'request_spec_shared_examples'
require 'presenters/v3/space_presenter'
require 'presenters/v3/organization_presenter'

RSpec.describe 'Routes Request' do
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }
  let!(:org) { VCAP::CloudController::Organization.make(created_at: 1.hour.ago) }
  let!(:space) { VCAP::CloudController::Space.make(name: 'a-space', created_at: 1.hour.ago, organization: org) }

  let(:space_json_generator) do
    lambda { |s|
      presented_space = VCAP::CloudController::Presenters::V3::SpacePresenter.new(s).to_hash
      presented_space[:created_at] = iso8601
      presented_space[:updated_at] = iso8601
      presented_space
    }
  end

  let(:org_json_generator) do
    lambda { |o|
      presented_space = VCAP::CloudController::Presenters::V3::OrganizationPresenter.new(o).to_hash
      presented_space[:created_at] = iso8601
      presented_space[:updated_at] = iso8601
      presented_space
    }
  end

  before do
    TestConfig.override(kubernetes: {})
  end

  describe 'GET /v3/routes' do
    let(:other_space) { VCAP::CloudController::Space.make(name: 'b-space') }
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
    let!(:route_in_org) do
      VCAP::CloudController::Route.make(space: space, domain: domain, host: 'host-1', path: '/path1', guid: 'route-in-org-guid')
    end
    let!(:route_in_other_org) do
      VCAP::CloudController::Route.make(space: other_space, host: 'host-2', path: '/path2', guid: 'route-in-other-org-guid')
    end
    let!(:route_in_org_dest_web) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route_in_org, process_type: 'web') }
    let!(:route_in_org_dest_worker) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route_in_org, process_type: 'worker') }
    let(:api_call) { lambda { |user_headers| get '/v3/routes', nil, user_headers } }
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
        destinations: match_array([
          {
            guid: route_in_org_dest_web.guid,
            app: {
              guid: app_model.guid,
              process: {
                type: route_in_org_dest_web.process_type
              }
            },
            weight: route_in_org_dest_web.weight,
            port: route_in_org_dest_web.presented_port,
            protocol: 'http1'
          },
          {
            guid: route_in_org_dest_worker.guid,
            app: {
              guid: app_model.guid,
              process: {
                type: route_in_org_dest_worker.process_type
              }
            },
            weight: route_in_org_dest_worker.weight,
            port: route_in_org_dest_worker.presented_port,
            protocol: 'http1'
          }
        ]),
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
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route_in_org.guid}) },
          space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{route_in_org.space.guid}) },
          destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route_in_org.guid}\/destinations) },
          domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{route_in_org.domain.guid}) }
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
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route_in_other_org.guid}) },
          space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{route_in_other_org.space.guid}) },
          destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route_in_other_org.guid}\/destinations) },
          domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{route_in_other_org.domain.guid}) }
        }
      }
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::Route }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/routes?#{filters}", nil, headers }
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
            space_guids: ['foo', 'bar'],
            service_instance_guids: ['baz', 'qux'],
            organization_guids: ['foo', 'bar'],
            domain_guids: ['foo', 'bar'],
            app_guids: ['foo', 'bar'],
            guids: ['foo', 'bar'],
            paths: ['foo', 'bar'],
            hosts: 'foo',
            ports: 636,
            include: 'domain',
            label_selector: 'foo,bar',
            created_ats:  "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
            updated_ats: { gt: Time.now.utc.iso8601 },
          }
        end
      end
    end

    context 'when the user is a member in the routes org' do
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_objects: [route_in_org_json]
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
              route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{domain1.guid}/route_reservations) }
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
              route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{domain1.guid}/route_reservations) }
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
              route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{domain2.guid}/route_reservations) }
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
            links: {
              self: { href: "http://api2.vcap.me/v3/routes/#{route1_domain1.guid}" },
              space: { href: "http://api2.vcap.me/v3/spaces/#{space.guid}" },
              destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route1_domain1.guid}\/destinations) },
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
          links: {
            self: { href: 'http://api2.vcap.me/v3/routes/route-without-host' },
            space: { href: "http://api2.vcap.me/v3/spaces/#{space.guid}" },
            destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/route-without-host\/destinations) },
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
          links: {
            self: { href: 'http://api2.vcap.me/v3/routes/route-without-host2' },
            space: { href: "http://api2.vcap.me/v3/spaces/#{space.guid}" },
            destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/route-without-host2\/destinations) },
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
          links: {
            self: { href: 'http://api2.vcap.me/v3/routes/route-without-path' },
            space: { href: "http://api2.vcap.me/v3/spaces/#{space.guid}" },
            destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/route-without-path\/destinations) },
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
          allow(routing_api_client).to receive(:enabled?).and_return(true)
          allow(routing_api_client).to receive(:router_group).and_return(router_group)
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
            expect(parsed_response['resources'].map { |resource| resource['port'] }).to contain_exactly(route_with_ports_0.port, route_with_ports_1.port)
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
          expect(parsed_response['resources'].map { |resource| resource['guid'] }).to contain_exactly('route-with-service-instance-one', 'route-with-service-instance-two')
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
          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered routes for "in" label selector with space guids' do
          get "/v3/routes?label_selector=animal in (dog)&space_guids=#{space.guid}", nil, admin_header

          expect(last_response).to have_status_code(200)
          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&page=1&per_page=50&space_guids=#{space.guid}" },
            'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&page=1&per_page=50&space_guids=#{space.guid}" },
            'next' => nil,
            'previous' => nil
          }

          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered routes for "in" label selector with org filters' do
          get "/v3/routes?label_selector=animal in (dog)&organization_guids=#{org.guid}", nil, admin_header

          expect(last_response).to have_status_code(200), last_response.body
          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&organization_guids=#{org.guid}&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&organization_guids=#{org.guid}&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered routes for "in" label selector with domain filters' do
          get "/v3/routes?label_selector=animal in (dog)&domain_guids=#{domain1.guid}", nil, admin_header

          expect(last_response).to have_status_code(200), last_response.body
          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/routes?domain_guids=#{domain1.guid}&label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/routes?domain_guids=#{domain1.guid}&label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered routes for "in" label selector with host filters' do
          get '/v3/routes?label_selector=animal in (dog)&hosts=hall', nil, admin_header

          expect(last_response).to have_status_code(200), last_response.body
          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/routes?hosts=hall&label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/routes?hosts=hall&label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end

        it 'returns a 200 and the filtered routes for "in" label selector with path filters' do
          get '/v3/routes?label_selector=animal in (dog)&paths=/oates', nil, admin_header

          expect(last_response).to have_status_code(200)
          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&page=1&paths=%2Foates&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+in+%28dog%29&page=1&paths=%2Foates&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route1.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end
      end

      it 'returns a 200 and the filtered routes for "notin" label selector' do
        get '/v3/routes?label_selector=animal notin (dog)', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 3,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+notin+%28dog%29&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal+notin+%28dog%29&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route2.guid, route_in_org.guid, route_in_other_org.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered routes for "=" label selector' do
        get '/v3/routes?label_selector=animal=dog', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%3Ddog&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%3Ddog&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered domains for "==" label selector' do
        get '/v3/routes?label_selector=animal==dog', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%3D%3Ddog&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%3D%3Ddog&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered routes for "!=" label selector' do
        get '/v3/routes?label_selector=animal!=dog', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 3,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%21%3Ddog&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%21%3Ddog&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route2.guid, route_in_org.guid, route_in_other_org.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered routes for "=" label selector' do
        get '/v3/routes?label_selector=animal=cow,santa=claus', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%3Dcow%2Csanta%3Dclaus&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=animal%3Dcow%2Csanta%3Dclaus&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered routes for existence label selector' do
        get '/v3/routes?label_selector=santa', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=santa&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=santa&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered routes for non-existence label selector' do
        get '/v3/routes?label_selector=!santa', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
          'total_results' => 3,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/routes?label_selector=%21santa&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/routes?label_selector=%21santa&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(route1.guid, route_in_org.guid, route_in_other_org.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end

    describe 'eager loading' do
      it 'eager loads associated resources that the presenter specifies' do
        expect(VCAP::CloudController::RouteFetcher).to receive(:fetch).with(
          anything,
          anything,
          hash_including(eager_loaded_associations: [:domain, :space, :route_mappings, :labels, :annotations])
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

  describe 'GET /v3/routes/:guid' do
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
    let(:route) { VCAP::CloudController::Route.make(space: space, domain: domain) }
    let(:api_call) { lambda { |user_headers| get "/v3/routes/#{route.guid}", nil, user_headers } }
    let(:route_json) do
      {
        guid: route.guid,
        protocol: route.domain.protocols[0],
        host: route.host,
        path: route.path,
        port: nil,
        url: "#{route.host}.#{route.domain.name}#{route.path}",
        created_at: iso8601,
        updated_at: iso8601,
        destinations: [],
        relationships: {
          space: {
            data: { guid: route.space.guid }
          },
          domain: {
            data: { guid: route.domain.guid }
          }
        },
        metadata: {
          labels: {},
          annotations: {}
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
          space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{route.space.guid}) },
          destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
          domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{route.domain.guid}) }
        }
      }
    end

    context 'when the user is a member in the routes org' do
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_object: route_json
        )

        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get "/v3/routes/#{route.guid}", nil, base_json_headers
        expect(last_response).to have_status_code(401)
      end
    end

    describe 'includes' do
      context 'when including domains' do
        let(:domain_json) do
          {
            guid: domain.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: domain.name,
            internal: false,
            router_group: nil,
            supported_protocols: ['http'],
            metadata: {
              labels: {},
              annotations: {}
            },
            relationships: {
              organization: {
                data: { guid: domain.owning_organization.guid }
              },
              shared_organizations: {
                data: []
              }
            },
            links: {
              self: { href: "#{link_prefix}/v3/domains/#{domain.guid}" },
              organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3/organizations/#{domain.owning_organization.guid}) },
              route_reservations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{domain.guid}/route_reservations) },
              shared_organizations: { href: %r(#{Regexp.escape(link_prefix)}\/v3/domains/#{domain.guid}/relationships/shared_organizations) },
            }
          }
        end
        let(:route_json) do
          {
            guid: route.guid,
            protocol: route.domain.protocols[0],
            host: route.host,
            path: route.path,
            port: nil,
            url: "#{route.host}.#{route.domain.name}#{route.path}",
            created_at: iso8601,
            updated_at: iso8601,
            destinations: [],
            relationships: {
              space: {
                data: { guid: route.space.guid }
              },
              domain: {
                data: { guid: route.domain.guid }
              }
            },
            metadata: {
              labels: {},
              annotations: {}
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
              space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{route.space.guid}) },
              destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
              domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{route.domain.guid}) }
            },
            included: { domains: [domain_json] }
          }
        end

        it 'includes the domain for the route' do
          get "/v3/routes/#{route.guid}?include=domain", nil, admin_header
          expect(last_response).to have_status_code(200), last_response.body
          expect(parsed_response).to match_json_response(route_json)
        end
      end

      context 'when including spaces and orgs' do
        it 'includes the unique spaces and organizations for the routes' do
          get "/v3/routes/#{route.guid}?include=space,space.organization", nil, admin_header
          expect(last_response).to have_status_code(200)
          expect(parsed_response['included']).to match_json_response(
            'spaces' => [
              space_json_generator.call(space),
            ],
            'organizations' => [
              org_json_generator.call(org),
            ])
        end
      end
    end
  end

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
              },
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
              },
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
              },
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
              },
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
              space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
              destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
              domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) },
            },
            metadata: {
              labels: {},
              annotations: {}
            },
          }
        end

        describe 'valid routes' do
          let(:api_call) { lambda { |user_headers| post '/v3/routes', params.to_json, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 403,
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
              },
            },
            metadata: {
              labels: { potato: 'yam' },
              annotations: { style: 'mashed' }
            }
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
              },
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
              space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
              destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
              domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) }
            },
            metadata: {
              labels: { potato: 'yam' },
              annotations: { style: 'mashed' }
            }
          }
        end

        describe 'valid routes' do
          it_behaves_like 'permissions for single object endpoint', ['admin'] do
            let(:api_call) { lambda { |user_headers| post '/v3/routes', params.to_json, user_headers } }

            let(:expected_codes_and_responses) do
              h = Hash.new(
                code: 403,
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
                organization_guid: org.guid,
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
              },
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
              },
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
              space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
              destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
              domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) }
            },
            metadata: {
              labels: {},
              annotations: {}
            },
          }
        end

        describe 'valid routes' do
          let(:api_call) { lambda { |user_headers| post '/v3/routes', params.to_json, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 403,
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
              },
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
              },
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
              },
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
              space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
              destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
              domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) }
            },
            metadata: {
              labels: {},
              annotations: {}
            },
          }
        end

        describe 'valid routes' do
          let(:api_call) { lambda { |user_headers| post '/v3/routes', params.to_json, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 403,
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
              },
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
              },
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
              space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
              destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
              domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) }
            },
            metadata: {
              labels: {},
              annotations: {}
            },
          }
        end

        describe 'valid routes' do
          let(:api_call) { lambda { |user_headers| post '/v3/routes', params.to_json, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 403,
            )
            h['admin'] = {
              code: 201,
              response_object: route_json
            }
            h['space_developer'] = {
              code: 422,
            }
            h['space_supporter'] = {
              code: 422,
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
            external_protocol: 'https',
          )
          allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
          allow(routing_api_client).to receive(:enabled?).and_return(true)
          allow(routing_api_client).to receive(:router_group).and_return(router_group)
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
              },
            }
          }
        end

        let(:api_call) { lambda { |user_headers| post '/v3/routes', params.to_json, user_headers } }

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
              },
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
              space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
              destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
              domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) }
            },
            metadata: {
              labels: {},
              annotations: {}
            },
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 403,
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
                },
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
                  },
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
            },
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
            },
          },
          metadata: {
            labels: {},
            annotations: {}
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
            space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
            destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
            domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) }
          }
        }
      end

      describe 'valid routes' do
        let(:api_call) { lambda { |user_headers| post '/v3/routes', params.to_json, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
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
              },
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
              },
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
              },
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
              },
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
              space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
              destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
              domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) },
            },
            metadata: {
              labels: {},
              annotations: {}
            }
          }
        end

        describe 'valid routes' do
          let(:api_call) { lambda { |user_headers| post '/v3/routes', params.to_json, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 403,
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
            },
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
            },
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
              },
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
              },
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
            },
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
            },
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
      let(:api_call) { lambda { |user_headers| post '/v3/routes', params.to_json, user_headers } }

      let(:params) do
        {
          host: 'host',
          relationships: {
            space: {
              data: { guid: space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            },
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
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
            space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
            destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
            domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
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
              },
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
              },
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
            },
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
            },
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
            },
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
                },
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
          allow(routing_api_client).to receive(:enabled?).and_return true
          allow(routing_api_client).to receive(:router_group).and_return nil
        end

        it 'returns a 503 with a helpful error message' do
          post '/v3/routes', params.to_json, headers

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors'][0]['detail']).to eq 'Route could not be created because the specified domain does not have a valid router group.'
        end
      end
    end
  end

  describe 'PATCH /v3/routes/:guid' do
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
    let(:route) { VCAP::CloudController::Route.make(space: space, domain: domain, host: '') }
    let(:api_call) { lambda { |user_headers| patch "/v3/routes/#{route.guid}", params.to_json, user_headers } }
    let(:params) do
      {
        metadata: {
          labels: {
            potato: 'fingerling',
            style: 'roasted'
          },
          annotations: {
            potato: 'russet',
            style: 'fried'
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
          },
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
          space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
          destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
          domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) }
        },
        metadata: {
          labels: {
            potato: 'fingerling',
            style: 'roasted'
          },
          annotations: {
            potato: 'russet',
            style: 'fried'
          }
        }
      }
    end

    context 'when the user logged in' do
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
        h['admin'] = { code: 200, response_object: route_json }
        h['no_role'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['space_developer'] = { code: 200, response_object: route_json }
        h['space_supporter'] = { code: 200, response_object: route_json }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when the user is not a member in the routes org' do
      let(:other_space) { VCAP::CloudController::Space.make }
      let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: other_space.organization) }
      let(:route) { VCAP::CloudController::Route.make(space: other_space, domain: domain, host: '') }

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
              data: { guid: other_space.guid }
            },
            domain: {
              data: { guid: domain.guid }
            },
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}) },
            space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{other_space.guid}) },
            destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{UUID_REGEX}\/destinations) },
            domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{domain.guid}) }
          },
          metadata: {
            labels: {
              potato: 'fingerling',
              style: 'roasted'
            },
            annotations: {
              potato: 'russet',
              style: 'fried'
            }
          }
        }
      end
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = {
          code: 200,
          response_object: route_json
        }
        h['admin_read_only'] = {
          code: 403
        }
        h['global_auditor'] = {
          code: 403
        }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when route does not exist' do
      it 'returns a 404 with a helpful error message' do
        patch "/v3/routes/#{user.guid}", params.to_json, admin_header

        expect(last_response).to have_status_code(404)
        expect(last_response).to have_error_message('Route not found')
      end
    end

    context 'when request input message is invalid' do
      let(:params_with_invalid_input) do
        {
          disallowed_key: 'val'
        }
      end

      it 'returns a 422' do
        patch "/v3/routes/#{route.guid}", params_with_invalid_input.to_json, admin_header

        expect(last_response).to have_status_code(422)
      end
    end

    context 'when metadata is given with invalid format' do
      let(:params_with_invalid_metadata_format) do
        {
          metadata: {
            labels: {
              "": 'mashed',
              "/potato": '.value.'
            }
          }
        }
      end

      it 'returns a 422' do
        patch "/v3/routes/#{route.guid}", params_with_invalid_metadata_format.to_json, admin_header

        expect(last_response).to have_status_code(422)
        expect(parsed_response['errors'][0]['detail']).to match(/Metadata [\w\s]+ error/)
      end
    end

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        patch "/v3/routes/#{route.guid}", nil, base_json_headers
        expect(last_response).to have_status_code(401)
      end
    end
  end

  describe 'DELETE /v3/routes/:guid' do
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }
    let(:route) { VCAP::CloudController::Route.make(space: space, domain: domain) }
    let(:api_call) { lambda { |user_headers| delete "/v3/routes/#{route.guid}", nil, user_headers } }
    let(:db_check) do
      lambda do
        expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/[a-fA-F0-9-]+))

        execute_all_jobs(expected_successes: 1, expected_failures: 0)
        get "/v3/routes/#{route.guid}", {}, admin_headers
        expect(last_response).to have_status_code(404)
      end
    end

    context 'deleting metadata' do
      it_behaves_like 'resource with metadata' do
        let(:resource) { route }
        let(:api_call) do
          -> { delete "/v3/routes/#{route.guid}", nil, admin_header }
        end
      end
    end

    context 'when the user is a member in the routes org' do
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h['admin'] = { code: 202 }
        h['space_developer'] = { code: 202 }
        h['space_supporter'] = { code: 202 }
        h
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS do
        let(:expected_event_hash) do
          {
            type: 'audit.route.delete-request',
            actee: route.guid,
            actee_type: 'route',
            actee_name: route.host,
            metadata: { request: { recursive: true } }.to_json,
            space_guid: space.guid,
            organization_guid: org.guid,
          }
        end
      end

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        delete "/v3/routes/#{route.guid}", nil, base_json_headers
        expect(last_response).to have_status_code(401)
      end
    end
  end

  describe 'GET /v3/routes/:guid/relationships/shared_spaces' do
    let(:api_call) { lambda { |user_headers| get "/v3/routes/#{guid}/relationships/shared_spaces", nil, user_headers } }
    let(:target_space_1) { VCAP::CloudController::Space.make(organization: org) }
    let(:route) {
      route = VCAP::CloudController::Route.make(space: space)
      route.add_shared_space(target_space_1)
      route
    }
    let(:guid) { route.guid }
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let!(:feature_flag) do
      VCAP::CloudController::FeatureFlag.make(name: 'route_sharing', enabled: true, error_message: nil)
    end

    before do
      org.add_user(user)
      target_space_1.add_developer(user)
    end

    describe 'permissions' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) do
          h = Hash.new(code: 200, response_object: {
            data: [
              {
                guid: target_space_1.guid
              }
            ],
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route.guid}\/relationships\/shared_spaces) },
            }
          })

          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
          h
        end
      end
    end

    describe 'when route_sharing flag is disabled' do
      before do
        feature_flag.enabled = false
        feature_flag.save
      end

      it 'makes users unable to unshare routes' do
        api_call.call(space_dev_headers)

        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => 'Feature Disabled: route_sharing',
              'title' => 'CF-FeatureDisabled',
              'code' => 330002,
            })
        )
      end
    end

    it 'responds with 404 when the route does not exist' do
      get '/v3/routes/some-fake-guid/relationships/shared_spaces', nil, space_dev_headers

      expect(last_response).to have_status_code(404)
      expect(parsed_response['errors']).to include(
        include(
          {
            'detail' => 'Route not found',
            'title' => 'CF-ResourceNotFound'
          })
      )
    end
  end

  describe 'POST /v3/routes/:guid/relationships/shared_spaces' do
    let(:api_call) { lambda { |user_headers| post "/v3/routes/#{guid}/relationships/shared_spaces", request_body.to_json, user_headers } }
    let(:target_space_1) { VCAP::CloudController::Space.make(organization: org) }
    let(:target_space_2) { VCAP::CloudController::Space.make(organization: org) }
    let(:request_body) do
      {
        'data' => [
          { 'guid' => target_space_1.guid },
          { 'guid' => target_space_2.guid }
        ]
      }
    end
    let(:route) { VCAP::CloudController::Route.make(space: space) }
    let(:guid) { route.guid }
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let!(:feature_flag) do
      VCAP::CloudController::FeatureFlag.make(name: 'route_sharing', enabled: true, error_message: nil)
    end

    before do
      org.add_user(user)
      target_space_1.add_developer(user)
      target_space_2.add_developer(user)
    end

    describe 'permissions' do
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)

        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }

        h['admin'] = { code: 200 }
        h['space_developer'] = { code: 200 }
        h['space_supporter'] = { code: 200 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when target organization is suspended' do
        let(:target_space_1) do
          space = VCAP::CloudController::Space.make
          space.organization.add_user(user)
          space.organization.update(status: VCAP::CloudController::Organization::SUSPENDED)
          space
        end

        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 422 } }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    it 'shares the route to the target space and logs audit event' do
      api_call.call(space_dev_headers)

      expect(last_response.status).to eq(200)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type: 'audit.route.share',
        actor: user.guid,
        actee_type: 'route',
        actee_name: route.host,
        space_guid: space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata['target_space_guids']).to include(target_space_1.guid, target_space_2.guid)

      route.reload
      expect(route.shared_spaces).to include(target_space_1, target_space_2)
    end

    it 'reports that the route is now shared' do
      api_call.call(space_dev_headers)

      expect(last_response.status).to eq(200)
      route.reload
      expect(route.shared_spaces).to include(target_space_1, target_space_2)
      expect(route.shared?).to be_truthy
    end

    it 'reports that the route is not shared when it has not been shared' do
      route.reload
      expect(route.shared_spaces).to be_empty
      expect(route.shared?).to be_falsey
    end

    describe 'when route_sharing flag is disabled' do
      before do
        feature_flag.enabled = false
        feature_flag.save
      end

      it 'makes users unable to share routes' do
        api_call.call(space_dev_headers)

        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => 'Feature Disabled: route_sharing',
              'title' => 'CF-FeatureDisabled',
              'code' => 330002,
            })
        )
      end
    end

    it 'responds with 404 when the route does not exist' do
      post '/v3/routes/some-fake-guid/relationships/shared_spaces', request_body.to_json, space_dev_headers

      expect(last_response).to have_status_code(404)
      expect(parsed_response['errors']).to include(
        include(
          {
            'detail' => 'Route not found',
            'title' => 'CF-ResourceNotFound'
          })
      )
    end

    describe 'when the request body is invalid' do
      context 'when it is not a valid relationship' do
        let(:request_body) do
          {
            'data' => { 'guid' => target_space_1.guid }
          }
        end

        it 'should respond with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => 'Data must be an array',
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end

      context 'when there are additional keys' do
        let(:request_body) do
          {
            'data' => [
              { 'guid' => target_space_1.guid }
            ],
            'fake-key' => 'foo'
          }
        end

        it 'should respond with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unknown field(s): 'fake-key'",
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end
    end

    describe 'target space to share to' do
      context 'does not exist' do
        let(:target_space_guid) { 'fake-target' }
        let(:request_body) do
          {
            'data' => [
              { 'guid' => target_space_guid }
            ]
          }
        end

        it 'responds with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to share route #{route.uri} with spaces ['#{target_space_guid}']. " \
                            'Ensure the spaces exist and that you have access to them.',
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end

      context 'user does not have access to one of the target spaces' do
        let(:no_access_target_space) { VCAP::CloudController::Space.make(organization: org) }
        let(:request_body) do
          {
            'data' => [
              { 'guid' => no_access_target_space.guid },
              { 'guid' => target_space_1.guid }
            ]
          }
        end

        it 'responds with 422 and does not share the route' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to share route #{route.uri} with spaces ['#{no_access_target_space.guid}']. "\
                            'Ensure the spaces exist and that you have access to them.',
                'title' => 'CF-UnprocessableEntity'
              })
          )

          route.reload
          expect(route.shared?).to be_falsey
        end
      end

      context 'already owns the route' do
        let(:request_body) do
          {
            'data' => [
              { 'guid' => space.guid },
              { 'guid' => target_space_1.guid }
            ]
          }
        end

        it 'responds with 422 and does not share the route' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to share route '#{route.uri}' with space '#{space.guid}'. "\
                            'Routes cannot be shared into the space where they were created.',
                'title' => 'CF-UnprocessableEntity'
              })
          )

          route.reload
          expect(route.shared?).to be_falsey
        end
      end
    end

    describe 'errors while sharing' do
      # isolation segments?
    end
  end

  describe 'DELETE /v3/routes/:guid/relationships/shared_spaces/:space_guid' do
    let(:api_call) { lambda { |user_headers| delete "/v3/routes/#{guid}/relationships/shared_spaces/#{unshared_space_guid}", request_body.to_json, user_headers } }
    let(:target_space_1) { VCAP::CloudController::Space.make(organization: org) }
    let(:target_space_2) { VCAP::CloudController::Space.make(organization: org) }
    let(:target_space_3) { VCAP::CloudController::Space.make(organization: org) }
    let(:target_space_not_shared_with_route) { VCAP::CloudController::Space.make(organization: org) }
    let(:space_to_unshare) { target_space_2 }
    let(:unshared_space_guid) { space_to_unshare.guid }
    let(:request_body) { {} }
    let(:route) {
      route = VCAP::CloudController::Route.make(space: space)
      route.add_shared_space(target_space_1)
      route.add_shared_space(target_space_2)
      route.add_shared_space(target_space_3)
      route
    }
    let(:guid) { route.guid }
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let!(:feature_flag) do
      VCAP::CloudController::FeatureFlag.make(name: 'route_sharing', enabled: true, error_message: nil)
    end

    before do
      org.add_user(user)
      target_space_1.add_developer(user)
      target_space_2.add_developer(user)
      target_space_not_shared_with_route.add_developer(user)
    end

    describe 'permissions' do
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)

        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }

        h['admin'] = { code: 204 }
        h['space_developer'] = { code: 204 }
        h['space_supporter'] = { code: 204 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when target organization is suspended' do
        let(:space_to_unshare) do
          space = VCAP::CloudController::Space.make
          space.organization.add_user(user)
          space.add_developer(user)
          space.organization.update(status: VCAP::CloudController::Organization::SUSPENDED)
          space
        end

        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r|
            h[r] = {
              code: 422,
              errors: [{
                detail: "Unable to unshare route '#{route.uri}' from space '#{space_to_unshare.guid}'. The target organization is suspended.",
                title: 'CF-UnprocessableEntity',
                code: 10008
              }]
            }
          }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    it 'unshares the specified route from the target space and logs audit event' do
      expect(route.shared_spaces).to include(target_space_1, space_to_unshare, target_space_3)

      api_call.call(space_dev_headers)

      expect(last_response.status).to eq(204)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type: 'audit.route.unshare',
        actor: user.guid,
        actee_type: 'route',
        actee_name: route.host,
        space_guid: space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata['target_space_guid']).to eq(unshared_space_guid)

      route.reload
      expect(route.shared_spaces).to include(target_space_1, target_space_3)
    end

    describe 'when route_sharing flag is disabled' do
      before do
        feature_flag.enabled = false
        feature_flag.save
      end

      it 'makes users unable to unshare routes' do
        api_call.call(space_dev_headers)

        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => 'Feature Disabled: route_sharing',
              'title' => 'CF-FeatureDisabled',
              'code' => 330002,
            })
        )
      end
    end

    it 'responds with 204 when the route is not shared with the specified space' do
      delete "/v3/routes/#{route.guid}/relationships/shared_spaces/#{target_space_not_shared_with_route.guid}", request_body.to_json, space_dev_headers

      expect(last_response.status).to eq(204)
    end

    it "responds with 404 when the route doesn't exist" do
      delete "/v3/routes/some-fake-guid/relationships/shared_spaces/#{target_space_1.guid}", request_body.to_json, space_dev_headers

      expect(last_response).to have_status_code(404)
      expect(parsed_response['errors']).to include(
        include(
          {
            'detail' => 'Route not found',
            'title' => 'CF-ResourceNotFound'
          })
      )
    end

    context 'attempting to unshare from space that owns us' do
      let(:space_to_unshare) { space }
      it 'responds with 422 and does not unshare the roue' do
        api_call.call(space_dev_headers)

        expect(last_response.status).to eq(422)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => "Unable to unshare route '#{route.uri}' from space "\
                           "'#{space.guid}'. Routes cannot be removed from the space that owns them.",
              'title' => 'CF-UnprocessableEntity'
            })
        )

        route.reload
        expect(route.shared_spaces).to contain_exactly(target_space_1, target_space_2, target_space_3)
      end
    end

    describe 'target space to unshare with' do
      context 'does not exist' do
        let(:unshared_space_guid) { 'fake-target' }

        it 'responds with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to unshare route '#{route.uri}' from space '#{unshared_space_guid}'. " \
                            'Ensure the space exists and that you have access to it.',
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end

      context 'user does not have read access to the target space' do
        let(:unshared_space_guid) { VCAP::CloudController::Space.make(organization: org).guid }

        it 'responds with 422 and does not share the route' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to unshare route '#{route.uri}' from space '#{unshared_space_guid}'. "\
                            'Ensure the space exists and that you have access to it.',
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end

      context 'user does not have write access to the target space' do
        let(:no_write_access_target_space) { VCAP::CloudController::Space.make(organization: org) }
        let(:unshared_space_guid) { no_write_access_target_space.guid }

        before do
          no_write_access_target_space.add_auditor(user)
        end

        it 'responds with 422 and does not share the route' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to unshare route '#{route.uri}' from space '#{no_write_access_target_space.guid}'. "\
                "You don't have write permission for the target space.",
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end
    end
  end

  describe 'PATCH /v3/routes/:guid/relationships/space' do
    let(:shared_domain) { VCAP::CloudController::SharedDomain.make }
    let(:route) { VCAP::CloudController::Route.make(space: space, domain: shared_domain) }
    let(:api_call) { lambda { |user_headers| patch "/v3/routes/#{route.guid}/relationships/space", request_body.to_json, user_headers } }
    let(:target_space) { VCAP::CloudController::Space.make(organization: org) }
    let(:request_body) do
      {
        data: { 'guid' => target_space.guid }
      }
    end
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let!(:feature_flag) do
      VCAP::CloudController::FeatureFlag.make(name: 'route_sharing', enabled: true, error_message: nil)
    end

    before do
      org.add_user(user)
      target_space.add_developer(user)
    end

    context 'when the user logged in' do
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
        h['admin'] = { code: 200 }
        h['no_role'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['space_developer'] = { code: 200 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when target organization is suspended' do
        let(:suspended_space) { VCAP::CloudController::Space.make }
        let(:request_body) do
          {
            data: { 'guid' => suspended_space.guid }
          }
        end

        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer].each { |r|
            h[r] = {
              code: 422,
              errors: [{
                detail: "Unable to transfer owner of route '#{route.uri}' to space '#{suspended_space.guid}'. The target organization is suspended.",
                title: 'CF-UnprocessableEntity',
                code: 10008
              }]
            }
          }
          h
        end

        before do
          suspended_space.organization.add_user(user)
          suspended_space.add_developer(user)
          suspended_space.organization.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    it 'changes the route owner to the given space and logs an event', isolation: :truncation do
      api_call.call(space_dev_headers)

      expect(last_response.status).to eq(200)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type: 'audit.route.transfer-owner',
        actor: user.guid,
        actee_type: 'route',
        actee_name: route.host,
        space_guid: space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata['target_space_guid']).to eq(target_space.guid)

      route.reload
      expect(route.space).to eq target_space
    end

    describe 'target space to transfer to' do
      context 'does not exist' do
        let(:target_space_guid) { 'fake-target' }
        let(:request_body) do
          {
            data: { 'guid' => target_space_guid }
          }
        end

        it 'responds with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to transfer owner of route '#{route.uri}' to space '#{target_space_guid}'. " \
                            'Ensure the space exists and that you have access to it.',
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end

      context 'user does not have read access to the target space' do
        let(:no_access_target_space) { VCAP::CloudController::Space.make(organization: org) }
        let(:request_body) do
          {
            data: { 'guid' => no_access_target_space.guid }
          }
        end

        it 'responds with 422 and does not share the route' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to transfer owner of route '#{route.uri}' to space '#{no_access_target_space.guid}'. "\
                            'Ensure the space exists and that you have access to it.',
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end
      context 'user does not have write access to the target space' do
        let(:no_write_access_target_space) { VCAP::CloudController::Space.make(organization: org) }
        let(:request_body) do
          {
            data: { 'guid' => no_write_access_target_space.guid }
          }
        end

        before do
          no_write_access_target_space.add_auditor(user)
        end

        it 'responds with 422 and does not share the route' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to transfer owner of route '#{route.uri}' to space '#{no_write_access_target_space.guid}'. "\
                "You don't have write permission for the target space.",
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end
    end

    it 'responds with 404 when the route does not exist' do
      patch '/v3/routes/some-fake-guid/relationships/space', request_body.to_json, space_dev_headers

      expect(last_response).to have_status_code(404)
      expect(parsed_response['errors']).to include(
        include(
          {
            'detail' => 'Route not found',
            'title' => 'CF-ResourceNotFound'
          })
      )
    end

    describe 'when the request body is invalid' do
      context 'when there are additional keys' do
        let(:request_body) do
          {
            data: { 'guid' => target_space.guid },
            'fake-key' => 'foo'
          }
        end

        it 'should respond with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unknown field(s): 'fake-key'",
                'title' => 'CF-UnprocessableEntity'
              })
          )
        end
      end
    end

    describe 'when route_sharing flag is disabled' do
      before do
        feature_flag.enabled = false
        feature_flag.save
      end

      it 'makes users unable to transfer-owner' do
        api_call.call(space_dev_headers)

        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => 'Feature Disabled: route_sharing',
              'title' => 'CF-FeatureDisabled',
              'code' => 330002,
            })
        )
      end
    end
  end

  describe 'GET /v3/apps/:app_guid/routes' do
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
    let(:route1) { VCAP::CloudController::Route.make(space: space) }
    let(:route2) { VCAP::CloudController::Route.make(space: space) }
    let!(:route3) { VCAP::CloudController::Route.make(space: space) }
    let!(:route_mapping1) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route1, process_type: 'web') }
    let!(:route_mapping2) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route2, process_type: 'admin') }
    let(:api_call) { lambda { |user_headers| get "/v3/apps/#{app_model.guid}/routes", nil, user_headers } }

    let(:route1_json) do
      {
        guid: route1.guid,
        protocol: route1.domain.protocols[0],
        host: route1.host,
        path: route1.path,
        port: nil,
        url: "#{route1.host}.#{route1.domain.name}#{route1.path}",
        created_at: iso8601,
        updated_at: iso8601,
        destinations: match_array([
          {
            guid: route_mapping1.guid,
            app: {
              guid: app_model.guid,
              process: {
                type: route_mapping1.process_type
              }
            },
            weight: route_mapping1.weight,
            port: route_mapping1.presented_port,
            protocol: 'http1'
          },
        ]),
        relationships: {
          space: {
            data: { guid: route1.space.guid }
          },
          domain: {
            data: { guid: route1.domain.guid }
          }
        },
        metadata: {
          labels: {},
          annotations: {}
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route1.guid}) },
          space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{route1.space.guid}) },
          destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route1.guid}\/destinations) },
          domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{route1.domain.guid}) }
        }
      }
    end

    let(:route2_json) do
      {
        guid: route2.guid,
        protocol: route2.domain.protocols[0],
        host: route2.host,
        path: route2.path,
        port: nil,
        url: "#{route2.host}.#{route2.domain.name}#{route2.path}",
        created_at: iso8601,
        updated_at: iso8601,
        destinations: match_array([
          {
            guid: route_mapping2.guid,
            app: {
              guid: app_model.guid,
              process: {
                type: route_mapping2.process_type
              }
            },
            weight: route_mapping2.weight,
            port: route_mapping2.presented_port,
            protocol: 'http1'
          },
        ]),
        relationships: {
          space: {
            data: { guid: route2.space.guid }
          },
          domain: {
            data: { guid: route2.domain.guid }
          }
        },
        metadata: {
          labels: {},
          annotations: {}
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route2.guid}) },
          space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{route2.space.guid}) },
          destinations: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/routes\/#{route2.guid}\/destinations) },
          domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{route2.domain.guid}) }
        }
      }
    end

    context 'when the user is a member in the app space' do
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_objects: [route1_json, route2_json]
        )

        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    context 'ports filter' do
      # Don't even think of converting the following hash to symbols ('type' => 'tcp' NOT type: 'tcp'), and you need to set the GUID
      let(:router_group) { VCAP::CloudController::RoutingApi::RouterGroup.new({ 'type' => 'tcp', 'reservable_ports' => '7777,8888,9999', 'guid' => 'some-guid' }) }
      let(:routing_api_client) { instance_double(VCAP::CloudController::RoutingApi::Client) }

      before do
        allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
        allow(routing_api_client).to receive(:enabled?).and_return(true)
        allow(routing_api_client).to receive(:router_group).and_return(router_group)
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
        let!(:route_mapping_1) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route_with_ports_1, process_type: 'web') }
        let!(:route_mapping_2) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route_with_ports_2, process_type: 'web') }

        it 'returns routes filtered by ports' do
          get "/v3/apps/#{app_model.guid}/routes?ports=7777,8888", nil, admin_header
          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'].size).to eq(1)
          expect(parsed_response['resources'].first['port']).to eq(route_with_ports_1.port)
        end
      end
    end

    describe 'eager loading' do
      it 'eager loads associated resources that the presenter specifies' do
        expect(VCAP::CloudController::RouteFetcher).to receive(:fetch).with(
          anything,
          anything,
          hash_including(eager_loaded_associations: [:domain, :space, :route_mappings, :labels, :annotations])
        ).and_call_original

        get "/v3/apps/#{app_model.guid}/routes", nil, admin_header
        expect(last_response).to have_status_code(200)
      end
    end
  end
end
