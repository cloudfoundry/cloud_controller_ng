require 'spec_helper'

RSpec.describe 'Domains Request' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: user_email, user_name: user_name) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:stack) { VCAP::CloudController::Stack.make }
  let(:user_email) { Sham.email }
  let(:user_name) { 'some-username' }
  let(:org) { space.organization }

  before do
    org.add_user(user)
    space.add_developer(user)
    VCAP::CloudController::Domain.dataset.destroy
  end

  describe 'GET /v3/domains' do
    let(:headers) { headers_for(user) }

    let!(:shared_domain) { VCAP::CloudController::SharedDomain.make(name: 'my-domain.edu', guid: 'shared_domain') }
    let!(:private_domain) { VCAP::CloudController::PrivateDomain.make(name: 'my-private-domain.edu', owning_organization: org, guid: 'private_domain') }

    it 'lists all domains' do
      get '/v3/domains', nil, headers

      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'pagination' => {
            'total_results' => 2,
            'total_pages' => 1,
            'first' => {
              'href' => "#{link_prefix}/v3/domains?page=1&per_page=50"
            },
            'last' => {
              'href' => "#{link_prefix}/v3/domains?page=1&per_page=50"
            },
            'next' => nil,
            'previous' => nil
          },
          'resources' => [
            {
              'guid' => 'shared_domain',
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'name' => 'my-domain.edu',
              'internal' => false,
              'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/domains/shared_domain" }
              }
            },
            {
              'guid' => 'private_domain',
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'name' => 'my-private-domain.edu',
              'internal' => false,
              'relationships' => {
                'organization' => {
                  'data' => { 'guid' => org.guid }
                },
              },
              'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/domains/private_domain" }
              }
            }
          ]
        }
      )
    end
  end

  describe 'POST /v3/domains' do
    context 'when not authenticated' do
      it 'returns 401' do
        params = {}
        headers = {}

        post '/v3/domains', params, headers

        expect(last_response.status).to eq(401)
      end
    end

    context 'when authenticated but not admin' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { headers_for(user) }

      it 'returns 403' do
        params = {}

        post '/v3/domains', params, headers

        expect(last_response.status).to eq(403)
      end
    end

    context 'when authenticated and admin' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { admin_headers_for(user) }

      context 'when provided valid arguments' do
        let(:params) do
          {
            name: 'my-domain.biz',
            internal: true,
          }
        end

        it 'returns 201' do
          post '/v3/domains', params.to_json, headers

          expect(last_response.status).to eq(201)

          domain = VCAP::CloudController::Domain.last

          expected_response = {
            'name' => params[:name],
            'internal' => params[:internal],
            'guid' => domain.guid,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/domains/#{domain.guid}"
              }
            }
          }
          expect(parsed_response).to be_a_response_like(expected_response)
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

        context 'with an existing unscoped domain as a subdomain' do
          let(:existing_domain) { VCAP::CloudController::SharedDomain.make }
          let(:domain) { "sub.#{existing_domain.name}" }

          let(:params) do
            {
              name: domain,
            }
          end

          it 'returns 201' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(201)

            expect(parsed_response['name']).to eq domain
          end
        end

        context 'with an existing scoped domain as a subdomain' do
          let(:existing_domain) { VCAP::CloudController::PrivateDomain.make }
          let(:domain) { "sub.#{existing_domain.name}" }

          let(:params) do
            {
              name: domain,
            }
          end

          it 'returns 422' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(422)

            expect(parsed_response['errors'][0]['detail']).to eq(
              %{The domain name "#{domain}" cannot be created because "#{existing_domain.name}" is already reserved by another domain}
            )
          end
        end
      end
    end
  end
end
