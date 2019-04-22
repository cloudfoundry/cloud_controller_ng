require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Domains Request' do
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
      let!(:non_visible_org) { VCAP::CloudController::Organization.make(guid: 'non-visible') }
      let!(:user_visible_org) { VCAP::CloudController::Organization.make(guid: 'visible') }

      # (domain)                        | (owning org)       | (visible orgs shared to)
      # (visible_owned_private_domain)  | (org)              | (non_visible_org, user_visible_org)
      # (visible_shared_private_domain) | (non_visible_org)  | (org)
      # (not_visible_private_domain)    | (non_visible_org)  | ()
      # (shared_domain)                 | ()                 | ()
      let!(:visible_owned_private_domain) {
        VCAP::CloudController::PrivateDomain.make(guid: 'domain1', name: 'domain1.com', owning_organization: org)
      }
      let!(:visible_shared_private_domain) {
        VCAP::CloudController::PrivateDomain.make(guid: 'domain2', name: 'domain2.com', owning_organization: non_visible_org)
      }
      let!(:not_visible_private_domain) {
        VCAP::CloudController::PrivateDomain.make(guid: 'domain3', name: 'domain3.com', owning_organization: non_visible_org)
      }
      let!(:shared_domain) {
        VCAP::CloudController::SharedDomain.make(guid: 'domain4', name: 'domain4.com')
      }

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
              data: contain_exactly(*shared_visible_orgs),
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{visible_owned_private_domain.guid}" },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) }
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
            self: { href: "#{link_prefix}/v3/domains/#{visible_shared_private_domain.guid}" },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{non_visible_org.guid}) }
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
            self: { href: "#{link_prefix}/v3/domains/#{not_visible_private_domain.guid}" },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{non_visible_org.guid}) }
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

      describe 'when filtering by name' do
        let(:shared_visible_orgs) { [{ guid: user_visible_org.guid }] }

        let(:api_call) { lambda { |user_headers| get "/v3/domains?names=#{visible_shared_private_domain.name}", nil, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_objects: [
              visible_shared_private_domain_json,
            ]
          )
          # because the user is a manager in the shared org, they have access to see the domain
          h['org_billing_manager'] = {
            code: 200,
            response_objects: []
          }
          h['no_role'] = {
            code: 200,
            response_objects: []
          }
          h.freeze
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
      end

      describe 'when filtering by owning organization guid' do
        let(:api_call) { lambda { |user_headers| get "/v3/domains?organization_guids=#{visible_shared_private_domain.owning_organization_guid}", nil, user_headers } }

        context 'when the user can read globally' do
          let(:expected_codes_and_responses) do
            Hash.new(
              code: 200,
              response_objects: [
                visible_shared_private_domain_json,
                not_visible_private_domain_json
              ]
            ).freeze
          end

          it_behaves_like 'permissions for list endpoint', GLOBAL_SCOPES
        end

        context 'when the user cannot read globally' do
          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                visible_shared_private_domain_json,
              ]
            )
            # because the user is a manager in the shared org, they have access to see the domain
            h['org_billing_manager'] = {
              code: 200,
              response_objects: []
            }
            h['no_role'] = {
              code: 200,
              response_objects: []
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

    describe 'when creating a shared domain' do
      let(:api_call) { lambda { |user_headers| post '/v3/domains', params.to_json, user_headers } }

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

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )
        h['admin'] = {
          code: 201,
          response_object: domain_json
        }
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    describe 'when creating a private domain' do
      let(:shared_org1) { VCAP::CloudController::Organization.make(guid: 'shared-org1') }
      let(:shared_org2) { VCAP::CloudController::Organization.make(guid: 'shared-org2') }

      let(:domain_json) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: params[:name],
          internal: false,
          relationships: {
            organization: {
              data: {
                guid: org.guid
              }
            },
            shared_organizations: {
              data: contain_exactly(
                { guid: shared_org1.guid },
                { guid: shared_org2.guid }
              )
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/domains\/#{UUID_REGEX}) },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) }
          }
        }
      end

      let(:private_domain_params) { {
        name: 'my-domain.com',
        relationships: {
          organization: {
            data: {
              guid: org.guid
            }
          },
          shared_organizations: {
            data: [
              { guid: shared_org1.guid },
              { guid: shared_org2.guid }
            ]

          }
        }
      }
      }

      before do
        shared_org1.add_manager(user)
        shared_org2.add_manager(user)
      end

      describe 'valid private domains' do
        let(:api_call) { lambda { |user_headers| post '/v3/domains', private_domain_params.to_json, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 403,
          )
          h['admin'] = {
            code: 201,
            response_object: domain_json

          }
          h['org_manager'] = {
            code: 201,
            response_object: domain_json

          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      describe 'invalid private domains' do
        let(:headers) { set_user_with_header_as_role(user: user, role: 'org_manager', org: org) }
        context 'when the org is suspended' do
          before do
            org.status = 'suspended'
            org.save
          end
          context 'when the user is not an admin' do
            it 'returns a 403' do
              post '/v3/domains', private_domain_params.to_json, headers

              expect(last_response.status).to eq(403)
              expect(parsed_response['errors'][0]['detail']).to eq('You are not authorized to perform the requested action')
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
          let!(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'private_domain_creation', enabled: false, error_message: 'my name is bob') }

          context 'when the user is not an admin' do
            it 'returns a 403' do
              post '/v3/domains', private_domain_params.to_json, headers

              expect(last_response.status).to eq(403)
              expect(parsed_response['errors'][0]['detail']).to eq('Feature Disabled: my name is bob')
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

        context 'when one of the shared orgs does not exist' do
          let(:missing_shared_org_relationship) do
            {
              relationships: {
                organization: {
                  data: {
                    guid: org.guid
                  }
                },
                shared_organizations: {
                  data: [
                    { guid: 'doesnt-exist' }
                  ]
                }
              }
            }.merge(params)
          end

          it 'returns a 422 with a helpful error message' do
            post '/v3/domains', missing_shared_org_relationship.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq "Organization with guid 'doesnt-exist' does not exist, or you do not have access to it."
          end
        end

        context 'when the user does not have proper permissions in one of the shared orgs' do
          let(:shared_org3) { VCAP::CloudController::Organization.make(guid: 'shared-org3') }

          let(:unwriteable_shared_org) do
            {
              relationships: {
                organization: {
                  data: {
                    guid: org.guid
                  }
                },
                shared_organizations: {
                  data: [
                    { guid: shared_org3.guid },
                    { guid: shared_org1.guid }
                  ]
                }
              }
            }.merge(params)
          end

          before do
            shared_org3.add_user(user)
          end

          it 'returns a 422 with a helpful error message' do
            post '/v3/domains', unwriteable_shared_org.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq "You do not have sufficient permissions for organization '#{shared_org3.name}' to share domain."
          end
        end

        context 'when the owning org is listed as a shared org' do
          let(:sharing_to_owning_org_relationship) do
            {
              relationships: {
                organization: {
                  data: {
                    guid: org.guid
                  }
                },
                shared_organizations: {
                  data: [
                    { guid: org.guid }
                  ]
                }
              }
            }.merge(params)
          end

          it 'returns a 422 with a helpful error message' do
            post '/v3/domains', sharing_to_owning_org_relationship.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq 'Domain cannot be shared with owning organization.'
          end
        end

        context 'when creating without an owning org' do
          let(:sharing_without_owning_org_relationship) do
            {
              relationships: {
                shared_organizations: {
                  data: [
                    { guid: org.guid }
                  ]
                }
              }
            }.merge(params)
          end

          it 'returns a 422 with a helpful error message' do
            post '/v3/domains', sharing_without_owning_org_relationship.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq 'Relationships cannot contain shared_organizations without an owning organization.'
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

  describe 'POST /v3/domains/:guid/relationships/shared_organizations' do
    let(:params) { { data: [] } }
    let(:private_domain) { VCAP::CloudController::PrivateDomain.make }
    let(:user_header) { admin_headers_for(user) }
    describe 'when updating shared orgs for a shared domain' do
      let(:shared_domain) { VCAP::CloudController::SharedDomain.make }

      it 'returns a 422' do
        post "/v3/domains/#{shared_domain.guid}/relationships/shared_organizations", params.to_json, user_header
        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'][0]['detail']).to eq('Domains can not be shared with other organizations unless they are scoped to an organization.')
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        post "/v3/domains/#{private_domain.guid}/relationships/shared_organizations", params.to_json, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end

    context 'when the user does not have the required scopes' do
      let(:user_header) { headers_for(user, scopes: ['cloud_controller.read']) }

      it 'returns a 403' do
        post "/v3/domains/#{private_domain.guid}/relationships/shared_organizations", params.to_json, user_header
        expect(last_response.status).to eq(403)
      end
    end

    context 'when the domain with specified guid does not exist' do
      it 'returns a 404' do
        post '/v3/domains/domain-does-not-exist/relationships/shared_organizations', params.to_json, user_header
        expect(last_response.status).to eq(404)
      end
    end

    context 'when sharing with owning org' do
      let(:params) { { data: [{ guid: private_domain.owning_organization_guid }] } }

      it 'returns a 422' do
        post "/v3/domains/#{private_domain.guid}/relationships/shared_organizations", params.to_json, user_header
        expect(last_response.status).to eq(422)
      end
    end

    context 'when sharing with invalid org' do
      let(:params) { { data: [{ guid: 'not-an-org' }] } }

      it 'returns a 422' do
        post "/v3/domains/#{private_domain.guid}/relationships/shared_organizations", params.to_json, user_header
        expect(last_response.status).to eq(422)
      end
    end

    describe 'when sharing orgs with a private domain' do
      let(:shared_org1) { VCAP::CloudController::Organization.make(guid: 'shared-org1') }

      let(:domain_shared_orgs) do
        {
          data: [{ guid: shared_org1.guid }, { guid: org.guid }]
        }
      end

      let(:private_domain_params) { {
        data: [{ guid: shared_org1.guid }, { guid: org.guid }]
      }
      }

      before do
        shared_org1.add_private_domain(private_domain)
        shared_org1.add_manager(user)
      end

      describe 'valid private domains' do
        let(:api_call) { lambda { |user_headers| post "/v3/domains/#{private_domain.guid}/relationships/shared_organizations", private_domain_params.to_json, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 422,
          )
          h['admin'] = {
            code: 200,
            response_object: domain_shared_orgs

          }
          h['org_manager'] = {
            code: 200,
            response_object: domain_shared_orgs

          }
          h['admin_read_only'] = {
            code: 403
          }
          h['global_auditor'] = {
            code: 403
          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
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
          response_object: shared_domain_json
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
              self: { href: "#{link_prefix}/v3/domains/#{private_domain.guid}" },
              organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) }
            }
          }
        }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: private_domain_json
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
                data: contain_exactly(*shared_organizations),
              }
            },
            links: {
              self: { href: "#{link_prefix}/v3/domains/#{private_domain.guid}" },
              organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) }
            }
          }
        }

        let(:api_call) { lambda { |user_headers| get "/v3/domains/#{private_domain.guid}", nil, user_headers } }

        context 'when the user can read in the shared organization' do
          let(:shared_organizations) { [{ guid: user_visible_org.guid }] }

          before do
            user_visible_org.add_manager(user)
          end

          let(:expected_codes_and_responses) do
            Hash.new(
              code: 200,
              response_object: private_domain_json
            ).freeze
          end

          it_behaves_like 'permissions for single object endpoint', LOCAL_ROLES
        end

        context 'when the user can read globally' do
          let(:shared_organizations) { [{ guid: non_visible_org.guid }, { guid: user_visible_org.guid }] }

          let(:expected_codes_and_responses) do
            Hash.new(
              code: 200,
              response_object: private_domain_json
            ).freeze
          end

          it_behaves_like 'permissions for single object endpoint', GLOBAL_SCOPES
        end
      end
    end
  end
end
