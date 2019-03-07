require 'spec_helper'

RSpec.describe 'Domains Request' do
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

      describe 'error cases' do
        context 'when provided invalid arguments' do
          let(:params) do
            {
              name: 'non-RFC-1035-compliant-domain-name'
            }
          end

          it 'returns 422' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(422)

            expected_err = 'Name can contain multiple subdomains, each having only alphanumeric characters and hyphens of up to 63 characters, see RFC 1035.'
            expect(parsed_response['errors'][0]['detail']).to eq expected_err
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
              pending('not implemented')

              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(422)

              expect(parsed_response['errors'][0]['detail']).to eq "The domain name \"#{existing_domain.name}\" is already reserved by another domain or route."
            end
          end

          context 'with an existing route' do
            let(:existing_route) { VCAP::CloudController::Route.make }

            let(:params) do
              {
                name: existing_route.fqdn,
              }
            end

            it 'returns 422' do
              pending('not implemented')

              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(422)

              expect(parsed_response['errors'][0]['detail']).to eq "The domain name \"#{existing_route.fqdn}\" is already reserved by another domain or route."
            end
          end

          context 'with an existing domain as a subdomain' do
            let(:existing_domain) { VCAP::CloudController::SharedDomain.make }
            let(:domain) { "sub.#{existing_domain.name}" }

            let(:params) do
              {
                name: domain,
              }
            end

            it 'returns 422' do
              pending('not implemented')

              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(422)

              expect(parsed_response['errors'][0]['detail']).to eq "The domain name \"#{domain}\" is already reserved by another domain or route."
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
              pending('not implemented')

              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(500)

              expect(parsed_response['errors'][0]['detail']).to eq "The domain name \"#{domain}\" is already reserved by another domain or route."
            end
          end
        end
      end
    end
  end
end
