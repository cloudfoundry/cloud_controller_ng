require 'spec_helper'

RSpec.shared_context 'CORS' do
  let(:authed_headers) do
    {
      'Authorization' => "bearer #{admin_token}",
      'Accept' => 'application/json',
      'Content-Type' => 'application/json'
    }
  end

  def make_preflight_request_with_origin(test_path, origin, method=nil, extra_headers={})
    headers = { 'Origin' => origin }
    headers['Access-Control-Request-Method'] = method unless method.nil?
    headers.merge!(extra_headers)
    make_options_request(test_path, headers)
  end

  [
    { app: 'v3 rails app', path: '/v3/processes', options_404: true },
    { app: 'v2 sinatra app', path: '/v2/info', options_404: true }
  ].each do |suite|
    describe suite[:app] do
      let(:test_path) { suite[:path] }

      context 'when the Origin header is not present' do
        it 'does not return any Access-Control headers and delegates to the initial request' do
          response = make_get_request(test_path, authed_headers)
          expect(response.code).to eq('200')
          expect(response['Access-Control']).to be_nil
          expect(response.json_body).to be_a(Hash)
        end
      end

      context 'when the Origin header is present' do
        describe 'a preflight request' do
          context 'and the origin is not in the whitelist' do
            it 'does not return any Access-Control headers and returns 404' do
              response = make_preflight_request_with_origin(test_path, 'http://corblimey.com', 'GET', authed_headers)
              expect(response['Access-Control']).to be_nil
              expect(response.code).to eq('404')
            end
          end

          context 'and the origin is a subset of a domain in the whitelist, but does not match' do
            it 'does not return any Access-Control headers and returns 404' do
              response = make_preflight_request_with_origin(test_path, 'http://talkoncorners.com.extra', 'GET', authed_headers)
              expect(response['Access-Control']).to be_nil
              expect(response.code).to eq('404')
            end
          end

          context 'and the origin matches a domain in the whitelist' do
            context 'but no Access-Control-Request-Method header is present' do
              it 'does not return any Access-Control headers' do
                response = make_preflight_request_with_origin(test_path, 'http://wildcarded.inblue.net', nil, authed_headers)
                expect(response['Access-Control']).to be_nil
              end
            end

            context 'and the Access-Control-Request-Method header is present' do
              it 'returns correct preflight response headers' do
                response = make_preflight_request_with_origin(test_path, 'http://bar.baz.inblue.net', 'PUT', authed_headers)
                expect(response.code).to eq('200')
                expect(response.body).to eq('')
                expect(response['Content-Type']).to eq('text/plain')
                expect(response['Vary']).to eq('Origin')
                expect(response['Access-Control-Allow-Origin']).to eq('http://bar.baz.inblue.net')
                expect(response['Access-Control-Allow-Credentials']).to eq('true')
                expect(response['Access-Control-Allow-Methods'].split(',')).to contain_exactly('PUT', 'POST', 'DELETE', 'GET')
                expect(response['Access-Control-Max-Age'].to_i).to be > 600
                expect(response['Access-Control-Expose-Headers'].split(',')).
                  to contain_exactly('x-cf-warnings', 'x-app-staging-log', 'range', 'location', VCAP::Request::HEADER_NAME.downcase)
                expect(response['Access-Control-Allow-Headers'].split(',')).to contain_exactly('origin', 'content-type', 'authorization')
              end

              context 'when the request asks to allow additional request headers' do
                it 'adds them to the Allow-Headers list' do
                  extra = { 'Access-Control-Request-Headers' => 'foo, bar, baz, Authorization' }
                  response = make_preflight_request_with_origin(test_path, 'http://bar.baz.inblue.net', 'PUT', authed_headers.merge(extra))
                  expect(response['Access-Control-Allow-Headers'].split(',')).to contain_exactly(
                    'origin', 'content-type', 'authorization', 'foo', 'bar', 'baz'
                  )
                end
              end
            end
          end
        end

        describe 'a simple request or actual request' do
          context 'and the origin is not in the whitelist' do
            it 'does not return any Access-Control headers and delegates to the initial request' do
              response = make_get_request(test_path, authed_headers.merge('Origin' => 'http://corblimey.com'))
              expect(response.code).to eq('200')
              expect(response['Access-Control']).to be_nil
              expect(response.json_body).to be_a(Hash)
            end
          end

          context 'and the origin is a subset of a domain in the whitelist, but does not match' do
            it 'does not return any Access-Control headers and delegates to the initial request' do
              response = make_get_request(test_path, authed_headers.merge('Origin' => 'http://talkoncorners.com.extra'))
              expect(response['Access-Control']).to be_nil
              expect(response.code).to eq('200')
              expect(response.json_body).to be_a(Hash)
            end
          end

          context 'and the origin matches an entry in the whitelist' do
            it 'returns correct CORS response headers and delegates to the initial request' do
              response = make_get_request(test_path, authed_headers.merge('Origin' => 'http://foo.inblue.net'))
              expect(response.code).to eq('200')
              expect(response.json_body).to be_a(Hash)
              expect(response['Access-Control-Allow-Origin']).to eq('http://foo.inblue.net')
              expect(response['Access-Control-Allow-Credentials']).to eq('true')
              expect(response['Access-Control-Expose-Headers'].split(',')).
                to contain_exactly('x-cf-warnings', 'x-app-staging-log', 'range', 'location', VCAP::Request::HEADER_NAME.downcase)
            end
          end
        end
      end
    end
  end
end
