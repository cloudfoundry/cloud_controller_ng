require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Domains Request', type: :request do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }

  before do
    VCAP::CloudController::Domain.dataset.destroy # this will clean up the seeded test domains
  end

  describe 'GET /v3/domains' do
    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get '/v3/domains'
        expect(last_response.status).to eq(401)
      end
    end

    describe 'when the user is logged in' do
      let!(:non_visible_org) { VCAP::CloudController::Organization.make }
      let!(:user_visible_org) { VCAP::CloudController::Organization.make }

      # (domain)                        | (owning org)       | (visible orgs shared to)
      # (visible_owned_private_domain)  | (org)              | (non_visible_org, user_visible_org)
      # (visible_shared_private_domain) | (non_visible_org)  | (org)
      # (not_visible_private_domain)    | (non_visible_org)  | ()
      # (shared_domain)                 | ()                 | ()
      let!(:visible_owned_private_domain) { VCAP::CloudController::PrivateDomain.make(guid: 'domain1', owning_organization: org) }
      let!(:visible_shared_private_domain) { VCAP::CloudController::PrivateDomain.make(guid: 'domain2', owning_organization: non_visible_org) }
      let!(:not_visible_private_domain) { VCAP::CloudController::PrivateDomain.make(guid: 'domain3', owning_organization: non_visible_org) }
      let!(:shared_domain) { VCAP::CloudController::SharedDomain.make(guid: 'domain4') }

      let(:visible_owned_private_domain_json) do
        {
          guid: visible_owned_private_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: visible_owned_private_domain.name,
          internal: false,
          relationships: {
            organization: {
              data: { guid: org.guid }
            },
            shared_organizations: {
              data: shared_visible_orgs,
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{visible_owned_private_domain.guid}" }
          }
        }
      end

      let(:visible_shared_private_domain_json) do
        {
          guid: visible_shared_private_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: visible_shared_private_domain.name,
          internal: false,
          relationships: {
            organization: {
              data: { guid: non_visible_org.guid }
            },
            shared_organizations: {
              data: [{ guid: org.guid }]
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{visible_shared_private_domain.guid}" }
          }
        }
      end

      let(:not_visible_private_domain_json) do
        {
          guid: not_visible_private_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: not_visible_private_domain.name,
          internal: false,
          relationships: {
            organization: {
              data: { guid: non_visible_org.guid }
            },
            shared_organizations: {
              data: []
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{not_visible_private_domain.guid}" }
          }
        }
      end

      let(:shared_domain_json) do
        {
          guid: shared_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: shared_domain.name,
          internal: false,
          relationships: {
            organization: {
              data: nil
            },
            shared_organizations: {
              data: []
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{shared_domain.guid}" }
          }
        }
      end

      before do
        non_visible_org.add_private_domain(visible_owned_private_domain)
        org.add_private_domain(visible_shared_private_domain)
        user_visible_org.add_private_domain(visible_owned_private_domain)
      end

      describe 'scope level permissions' do
        let(:shared_visible_orgs) { [{ guid: non_visible_org.guid }, { guid: user_visible_org.guid }] }

        context 'when the user does not have the required scopes' do
          let(:user_header) { headers_for(user, scopes: []) }

          it 'returns a 403' do
            get '/v3/domains', nil, user_header
            expect(last_response.status).to eq(403)
          end
        end

        context 'when the user has the required scopes' do
          let(:api_call) { lambda { |user_headers| get '/v3/domains', nil, user_headers } }
          let(:expected_codes_and_responses) do
            Hash.new(
              code: 200,
              response_objects: [
                visible_owned_private_domain_json,
                visible_shared_private_domain_json,
                not_visible_private_domain_json,
                shared_domain_json
              ]
            ).freeze
          end

          it_behaves_like 'permissions for list endpoint', GLOBAL_SCOPES
        end
      end

      describe 'org/space roles' do
        context 'when the domain is shared with an org that user is a billing manager' do
          before do
            user_visible_org.add_billing_manager(user)
          end

          let(:shared_visible_orgs) { [] }

          let(:api_call) { lambda { |user_headers| get '/v3/domains', nil, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                visible_owned_private_domain_json,
                visible_shared_private_domain_json,
                shared_domain_json,
              ]
            )
            h['org_billing_manager'] = {
              code: 200,
              response_objects: [
                shared_domain_json
              ]
            }
            h['no_role'] = {
              code: 200,
              response_objects: [
                shared_domain_json
              ]
            }
            h.freeze
          end

          it_behaves_like 'permissions for list endpoint', LOCAL_ROLES
        end

        context 'when the domain is shared with an org that user is an org manager' do
          before do
            user_visible_org.add_manager(user)
          end

          let(:shared_visible_orgs) { [{ guid: user_visible_org.guid }] }

          let(:api_call) { lambda { |user_headers| get '/v3/domains', nil, user_headers } }

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                visible_owned_private_domain_json,
                visible_shared_private_domain_json,
                shared_domain_json,
              ]
            )
            # because the user is a manager in the shared org, they have access to see the domain
            h['org_billing_manager'] = {
              code: 200,
              response_objects: [
                visible_owned_private_domain_json,
                shared_domain_json
              ]
            }
            h['no_role'] = {
              code: 200,
              response_objects: [
                visible_owned_private_domain_json,
                shared_domain_json
              ]
            }
            h.freeze
          end

          it_behaves_like 'permissions for list endpoint', LOCAL_ROLES
        end
      end
    end
  end

  describe 'POST /v3/domains' do
    let(:params) { { name: 'my-domain.com' } }

    let(:domain_json) do
      {
        guid: UUID_REGEX,
        created_at: iso8601,
        updated_at: iso8601,
        name: params[:name],
        internal: false,
        relationships: {
          organization: {
            data: nil
          },
          shared_organizations: {
            data: []
          }
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{UUID_REGEX}) }
        }
      }
    end

    describe 'when creating a shared domain' do
      let(:api_call) { lambda { |user_headers| post '/v3/domains', params.to_json, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
          response_objects: []
        )
        h['admin'] = {
          code: 201,
          response_objects: [
            domain_json
          ]
        }
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    describe 'when creating a private domain' do
      let(:org_relationship) do
        {
          relationships: {
            organization: {
              data: {
                guid: org.guid
              }
            }
          }
        }
      end

      let(:private_domain_params) { params.merge(org_relationship) }

      let(:api_call) { lambda { |user_headers| post '/v3/domains', private_domain_params.to_json, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
          response_objects: []
        )
        h['admin'] = {
          code: 201,
          response_objects: [
            domain_json.merge(org_relationship)
          ]
        }
        h['org_manager'] = {
          code: 201,
          response_objects: [
            domain_json.merge(org_relationship)
          ]
        }
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      describe 'invalid private domains' do
        let(:headers) { set_user_with_header_as_role(role: 'org_manager', org: org) }
        context 'when the org is suspended' do
          before do
            org.status = 'suspended'
            org.save
          end
          context 'when the user is not an admin' do
            it 'returns a 403' do
              post '/v3/domains', private_domain_params.to_json, headers

              expect(last_response.status).to eq(403)
            end
          end

          context 'when the user is an admin' do
            let(:headers) { set_user_with_header_as_role(role: 'admin') }
            it 'allows creation' do
              post '/v3/domains', private_domain_params.to_json, headers

              expect(last_response.status).to eq(201)
            end
          end
        end

        context 'when the feature flag is disabled' do
          let!(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'private_domain_creation', enabled: false) }

          context 'when the user is not an admin' do
            it 'returns a 403' do
              post '/v3/domains', private_domain_params.to_json, headers

              expect(last_response.status).to eq(403)
            end
          end

          context 'when the user is an admin' do
            let(:headers) { set_user_with_header_as_role(role: 'admin') }
            it 'allows creation' do
              post '/v3/domains', private_domain_params.to_json, headers

              expect(last_response.status).to eq(201)
            end
          end
        end

        context 'when the org doesnt exist' do
          let(:params) do
            {
              name: 'my-domain.biz',
              relationships: {
                organization: {
                  data: {
                    guid: 'non-existent-guid'
                  }
                }
              }
            }
          end

          it 'returns a 422 and a helpful error message' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq 'Organization with guid \'non-existent-guid\' does not exist or you do not have access to it.'
          end
        end

        context 'when the org has exceeded its private domains quota' do
          it 'returns a 422 and a helpful error message' do
            org.update(quota_definition: VCAP::CloudController::QuotaDefinition.make(total_private_domains: 0))

            post '/v3/domains', private_domain_params.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq "The number of private domains exceeds the quota for organization \"#{org.name}\""
          end
        end

        context 'when the domain is in the list of reserved private domains' do
          before do
            TestConfig.override({ reserved_private_domains: File.join(Paths::FIXTURES, 'config/reserved_private_domains.dat') })
          end

          it 'returns a 422 with a error message about reserved domains' do
            post '/v3/domains', private_domain_params.merge({ name: 'com.ac' }).to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq 'The "com.ac" domain is reserved and cannot be used for org-scoped domains.'
          end
        end
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        post '/v3/domains', params.to_json, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end

    context 'when the user does not have the required scopes' do
      let(:user_header) { headers_for(user, scopes: ['cloud_controller.read']) }

      it 'returns a 403' do
        post '/v3/domains', params.to_json, user_header
        expect(last_response.status).to eq(403)
      end
    end

    context 'when the params are invalid' do
      let(:headers) { set_user_with_header_as_role(role: 'admin') }
      context 'creating a sub domain of a domain scoped to another organization' do
        let(:organization_to_scope_to) { VCAP::CloudController::Organization.make }
        let(:existing_scoped_domain) { VCAP::CloudController::PrivateDomain.make }

        let(:params) do
          {
            name: "foo.#{existing_scoped_domain.name}",
            relationships: {
              organization: {
                data: {
                  guid: organization_to_scope_to.guid
                }
              }
            }
          }
        end

        it 'returns a 422 and an error' do
          post '/v3/domains', params.to_json, headers

          expect(last_response.status).to eq(422)

          expect(parsed_response['errors'][0]['detail']).to eq "The domain name \"#{params[:name]}\""\
" cannot be created because \"#{existing_scoped_domain.name}\" is already reserved by another domain"
        end
      end

      context 'when provided invalid arguments' do
        let(:params) do
          {
            name: "#{'f' * 63}$"
          }
        end

        it 'returns 422' do
          post '/v3/domains', params.to_json, headers

          expect(last_response.status).to eq(422)

          expected_err = ['Name does not comply with RFC 1035 standards',
                          'Name must contain at least one "."',
                          'Name subdomains must each be at most 63 characters',
                          'Name must consist of alphanumeric characters and hyphens']
          expect(parsed_response['errors'][0]['detail']).to eq expected_err.join(', ')
        end
      end

      describe 'collisions' do
        context 'with an existing domain' do
          let!(:existing_domain) { VCAP::CloudController::SharedDomain.make }

          let(:params) do
            {
              name: existing_domain.name,
            }
          end

          it 'returns 422' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq "The domain name \"#{existing_domain.name}\" is already in use"
          end
        end

        context 'with an existing route' do
          let(:existing_domain) { VCAP::CloudController::SharedDomain.make }
          let(:existing_route) { VCAP::CloudController::Route.make(domain: existing_domain) }
          let(:domain_name) { existing_route.fqdn }

          let(:params) do
            {
              name: domain_name,
            }
          end

          it 'returns 422' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to match(
              /The domain name "#{domain_name}" cannot be created because "#{existing_route.fqdn}" is already reserved by a route/
            )
          end
        end

        context 'with an existing route as a subdomain' do
          let(:existing_route) { VCAP::CloudController::Route.make }
          let(:domain) { "sub.#{existing_route.fqdn}" }

          let(:params) do
            {
              name: domain,
            }
          end

          it 'returns 422' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to match(
              /The domain name "#{domain}" cannot be created because "#{existing_route.fqdn}" is already reserved by a route/
            )
          end
        end
      end
    end
  end

  describe 'GET /v3/domains/:guid' do
    context 'when the domain does not exist' do
      let(:user_header) { headers_for(user) }

      it 'returns not found' do
        get '/v3/domains/does-not-exist', nil, user_header

        expect(last_response.status).to eq(404)
      end
    end

    context 'when getting a shared domain' do
      let(:shared_domain) { VCAP::CloudController::SharedDomain.make }

      let(:shared_domain_json) do
        {
          guid: shared_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: shared_domain.name,
          internal: false,
          relationships: {
            organization: {
              data: nil
            },
            shared_organizations: {
              data: []
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{shared_domain.guid}" }
          }
        }
      end

      let(:api_call) { lambda { |user_headers| get "/v3/domains/#{shared_domain.guid}", nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_objects: [shared_domain_json]
        )
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when getting a private domain' do
      context 'when the domain has not been shared' do
        let(:private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }

        let(:private_domain_json) {
          {
            guid: private_domain.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: private_domain.name,
            internal: false,
            relationships: {
              organization: {
                data: {
                  guid: org.guid
                }
              },
              shared_organizations: {
                data: []
              }
            },
            links: {
              self: { href: "#{link_prefix}/v3/domains/#{private_domain.guid}" }
            }
          }
        }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_objects: [private_domain_json]
          )
          h['org_billing_manager'] = {
            code: 404,
          }
          h['no_role'] = {
            code: 404,
          }
          h.freeze
        end

        let(:api_call) { lambda { |user_headers| get "/v3/domains/#{private_domain.guid}", nil, user_headers } }
        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the domain has been shared with another organization' do
        let!(:non_visible_org) { VCAP::CloudController::Organization.make }
        let!(:user_visible_org) { VCAP::CloudController::Organization.make }

        let(:private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }

        before do
          non_visible_org.add_private_domain(private_domain)
          user_visible_org.add_private_domain(private_domain)
          user_visible_org.add_billing_manager(user)
        end

        let(:private_domain_json) {
          {
            guid: private_domain.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: private_domain.name,
            internal: false,
            relationships: {
              organization: {
                data: {
                  guid: org.guid
                }
              },
              shared_organizations: {
                data: [
                  {
                    guid: user_visible_org.guid
                  }
                ]
              }
            },
            links: {
              self: { href: "#{link_prefix}/v3/domains/#{private_domain.guid}" }
            }
          }
        }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_objects: [private_domain_json]
          )
          h['org_billing_manager'] = {
            code: 404,
          }
          h['no_role'] = {
            code: 404,
          }
          h.freeze
        end

        let(:api_call) { lambda { |user_headers| get "/v3/domains/#{private_domain.guid}", nil, user_headers } }
        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end
  end
end
