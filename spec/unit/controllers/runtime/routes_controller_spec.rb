require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::RoutesController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:host) }
      it { expect(described_class).to be_queryable_by(:domain_guid) }
      it { expect(described_class).to be_queryable_by(:organization_guid) }
      it { expect(described_class).to be_queryable_by(:path) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          host:        { type: 'string', default: '' },
          domain_guid: { type: 'string', required: true },
          space_guid:  { type: 'string', required: true },
          app_guids:   { type: '[string]' },
          path:        { type: 'string' }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          host:        { type: 'string' },
          domain_guid: { type: 'string' },
          space_guid:  { type: 'string' },
          app_guids:   { type: '[string]' },
          path:        { type: 'string' }
        })
      end
    end

    describe 'Permissions' do
      context 'with a custom domain' do
        include_context 'permissions'

        before do
          @domain_a = PrivateDomain.make(owning_organization: @org_a)
          @obj_a    = Route.make(domain: @domain_a, space: @space_a)

          @domain_b = PrivateDomain.make(owning_organization: @org_b)
          @obj_b    = Route.make(domain: @domain_b, space: @space_b)
        end

        describe 'Org Level Permissions' do
          describe 'OrgManager' do
            let(:member_a) { @org_a_manager }
            let(:member_b) { @org_b_manager }

            include_examples 'permission enumeration', 'OrgManager',
              name: 'route',
              path: '/v2/routes',
              enumerate: 1
          end

          describe 'OrgUser' do
            let(:member_a) { @org_a_member }
            let(:member_b) { @org_b_member }

            include_examples 'permission enumeration', 'OrgUser',
              name: 'route',
              path: '/v2/routes',
              enumerate: 0
          end

          describe 'BillingManager' do
            let(:member_a) { @org_a_billing_manager }
            let(:member_b) { @org_b_billing_manager }

            include_examples 'permission enumeration', 'BillingManager',
              name: 'route',
              path: '/v2/routes',
              enumerate: 0
          end

          describe 'Auditor' do
            let(:member_a) { @org_a_auditor }
            let(:member_b) { @org_b_auditor }

            include_examples 'permission enumeration', 'Auditor',
              name: 'route',
              path: '/v2/routes',
              enumerate: 1
          end
        end

        describe 'App Space Level Permissions' do
          describe 'SpaceManager' do
            let(:member_a) { @space_a_manager }
            let(:member_b) { @space_b_manager }

            include_examples 'permission enumeration', 'SpaceManager',
              name: 'route',
              path: '/v2/routes',
              enumerate: 1
          end

          describe 'Developer' do
            let(:member_a) { @space_a_developer }
            let(:member_b) { @space_b_developer }

            include_examples 'permission enumeration', 'Developer',
              name: 'route',
              path: '/v2/routes',
              enumerate: 1
          end

          describe 'SpaceAuditor' do
            let(:member_a) { @space_a_auditor }
            let(:member_b) { @space_b_auditor }

            include_examples 'permission enumeration', 'SpaceAuditor',
              name: 'route',
              path: '/v2/routes',
              enumerate: 1
          end
        end
      end
    end

    describe 'Validation messages' do
      let(:domain) { SharedDomain.make }
      let(:space) { Space.make }

      it 'returns the RouteHostTaken message when no paths are used' do
        taken_host = 'someroute'
        Route.make(host: taken_host, domain: domain)

        post '/v2/routes', MultiJson.dump(host: taken_host, domain_guid: domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(210003)
      end

      it 'returns the RoutePathTaken message when paths conflict' do
        taken_host = 'someroute'
        path = '/%2Fsome%20path'
        post '/v2/routes', MultiJson.dump(host: taken_host, domain_guid: domain.guid, space_guid: space.guid, path: path), json_headers(admin_headers)

        post '/v2/routes', MultiJson.dump(host: taken_host, domain_guid: domain.guid, space_guid: space.guid, path: path), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(210004)
      end

      it 'returns the SpaceQuotaTotalRoutesExceeded message' do
        quota_definition = SpaceQuotaDefinition.make(total_routes: 0, organization: space.organization)
        space.space_quota_definition = quota_definition
        space.save

        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310005)
      end

      it 'returns the OrgQuotaTotalRoutesExceeded message' do
        quota_definition = space.organization.quota_definition
        quota_definition.total_routes = 0
        quota_definition.save

        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310006)
      end

      it 'returns the RouteInvalid message' do
        post '/v2/routes', MultiJson.dump(host: 'myexample!*', domain_guid: domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(210001)
      end

      it 'returns the a path cannot contain only "/"' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid, path: '/'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130004)
        expect(decoded_response['description']).to include('the path cannot be a single slash')
      end

      it 'returns the a path must start with a "/"' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid, path: 'a/'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130004)
        expect(decoded_response['description']).to include('the path must start with a "/"')
      end

      it 'returns the a path cannot contain "?" message for paths' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid, path: '/v2/zak?'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130004)
        expect(decoded_response['description']).to include('illegal "?" character')
      end

      it 'returns the PathInvalid message' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid, path: '/v2/zak?'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130004)
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes({ apps: [:get, :put, :delete] })
      end
    end

    describe 'POST /v2/routes' do
      let(:space) { Space.make }
      let(:user) { User.make }
      let(:req) {{
                   domain_guid: SharedDomain.make.guid,
                   space_guid:  space.guid,
                   host:        'example'
      }}

      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      context 'when route_creation feature flag is disabled' do
        before { FeatureFlag.make(name: 'route_creation', enabled: false, error_message: nil) }

        it 'returns FeatureDisabled for users' do
          post '/v2/routes', MultiJson.dump(req), headers_for(user)

          expect(last_response.status).to eq(403)
          expect(decoded_response['error_code']).to match(/FeatureDisabled/)
          expect(decoded_response['description']).to match(/route_creation/)
        end
      end
    end

    describe 'GET /v2/routes' do
      let(:organization) { Organization.make }
      let(:domain) { PrivateDomain.make(owning_organization: organization) }
      let(:space) { Space.make(organization: organization) }
      let(:route) { Route.make(domain: domain, space: space) }

      describe 'Filtering with Organization Guid' do
        context 'When Organization Guid Not Present' do
          it 'Return Resource length zero' do
            get 'v2/routes?q=organization_guid:notpresent', {}, admin_headers
            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(0)
          end
        end

        context 'When Organization Guid Present' do
          let(:first_route_info) { decoded_response.fetch('resources').first }
          let(:second_route_info) { decoded_response.fetch('resources').last }
          let(:space1) { Space.make(organization: organization) }
          let(:route1) { Route.make(domain: domain, space: space1) }

          it 'Allows filtering by organization_guid' do
            org_guid = organization.guid
            route_guid = route.guid

            get "v2/routes?q=organization_guid:#{org_guid}", {}, admin_headers

            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(1)
            expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
          end

          it 'Allows organization_guid query at any place in query ' do
            org_guid = organization.guid
            route_guid = route.guid
            domain_guid = domain.guid

            get "v2/routes?q=domain_guid:#{domain_guid}&q=organization_guid:#{org_guid}", {}, admin_headers

            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(1)
            expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
          end

          it 'Allows organization_guid query at any place in query with all querables' do
            org_guid = organization.guid
            taken_host = 'someroute'
            route_temp = Route.make(host: taken_host, domain: domain, space: space)
            route_guid = route_temp.guid
            domain_guid = domain.guid

            get "v2/routes?q=host:#{taken_host}&q=organization_guid:#{org_guid}&q=domain_guid:#{domain_guid}", {}, admin_headers

            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(1)
            expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
          end

          it 'Allows filtering at organization level' do
            org_guid = organization.guid
            route_guid = route.guid
            route1_guid = route1.guid

            get "v2/routes?q=organization_guid:#{org_guid}", {}, admin_headers

            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(2)
            expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
            expect(second_route_info.fetch('metadata').fetch('guid')).to eq(route1_guid)
          end
        end
      end
    end

    describe 'GET /v2/routes/reserved/domain/:domain_guid/host/:hostname' do
      let(:user) { User.make }

      context 'when the domain does not exist' do
        it 'returns a NOT_FOUND (404)' do
          get '/v2/routes/reserved/domain/nothere/host/myhost', nil, headers_for(user)
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the domain exists' do
        let(:route) { Route.make }

        context 'when the hostname is not reserved' do
          it 'returns a NOT_FOUND (404)' do
            get "/v2/routes/reserved/domain/#{route.domain_guid}/host/myhost", nil, headers_for(user)
            expect(last_response.status).to eq(404)
          end
        end

        context 'when the hostname is reserved' do
          it 'returns a NO_CONTENT (204)' do
            get "/v2/routes/reserved/domain/#{route.domain_guid}/host/#{route.host}", nil, headers_for(user)
            expect(last_response.status).to eq(204)
          end
        end

        context 'when a path is provided as a param' do
          context 'when the path does not exist' do
            it 'returns a NOT_FOUND (404)' do
              get "/v2/routes/reserved/domain/#{route.domain_guid}/host/#{route.host}?path=not_mypath", nil, headers_for(user)
              expect(last_response.status).to eq(404)
            end
          end

          context ' when the path does exist' do
            context 'when the path does not contain url encoding' do
              let(:path) { '/my_path' }
              let(:route) { Route.make(path: path) }

              it 'returns a NO_CONTENT (204)' do
                get "/v2/routes/reserved/domain/#{route.domain_guid}/host/#{route.host}?path=#{path}", nil, headers_for(user)
                expect(last_response.status).to eq(204)
              end
            end

            context 'when the path is url encoded' do
              let(:path) { '/my%20path' }
              let(:route) { Route.make(path: path) }

              it 'returns a NO_CONTENT' do
                uri_encoded_path = '%2Fmy%2520path'
                get "/v2/routes/reserved/domain/#{route.domain_guid}/host/#{route.host}?path=#{uri_encoded_path}", nil, headers_for(user)
                expect(last_response.status).to eq(204)
              end
            end
          end
        end
      end
    end
  end
end
