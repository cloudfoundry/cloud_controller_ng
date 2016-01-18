require 'spec_helper'

describe 'CORS', type: :integration do
  before(:all) do
    start_nats
    start_cc
  end

  after(:all) do
    stop_cc
    stop_nats
  end

  let(:authed_headers) do
    {
      'Authorization' => "bearer #{admin_token}",
      'Accept'        => 'application/json',
      'Content-Type'  => 'application/json'
    }
  end

  describe 'v3 rails app' do
    let(:test_path) { '/v3/processes' }

    context 'when the Origin header is not present' do
      it 'does not return any Access-Control headers (the request is not a CORS request)' do
        response = make_get_request(test_path, authed_headers)
        expect(response.code).to eq('200')
        expect(response['Access-Control']).to be_nil
      end

      it 'delegates to the initial request' do
        response = make_get_request(test_path, authed_headers)
        expect(response.code).to eq('200')
        expect(response.json_body).to be_a(Hash)
      end
    end

    context 'when the Origin header is present' do
      describe 'a preflight request' do
        def make_preflight_request_with_origin(origin, method=nil, extra_headers={})
          headers = {}
          headers = headers.merge({ 'Origin' => origin })
          headers = headers.merge({ 'Access-Control-Request-Method' => method }) unless method.nil?
          headers = headers.merge(extra_headers)

          make_options_request(test_path, headers)
        end

        context 'and the origin is not in the whitelist' do
          it 'does not return any Access-Control headers' do
            response = make_preflight_request_with_origin 'http://corblimey.com', 'GET', authed_headers
            expect(response['Access-Control']).to be_nil
          end

          it 'delegates to the initial request ( there is no options method for /v3/processes so we get a 404 )' do
            response = make_preflight_request_with_origin 'http://corblimey.com', 'GET', authed_headers
            expect(response.code).to eq('404')
          end
        end

        context 'and the origin is a subset of a domain in the whitelist, but does not match' do
          it 'does not return any Access-Control headers' do
            response = make_preflight_request_with_origin 'http://talkoncorners.com.extra', 'GET', authed_headers
            expect(response['Access-Control']).to be_nil
          end

          it 'delegates to the initial request ( there is no options method for /v3/processes so we get a 404 )' do
            response = make_preflight_request_with_origin 'http://talkoncorners.com.extra', 'GET', authed_headers
            expect(response.code).to eq('404')
          end
        end

        context 'and the origin matches a domain in the whitelist' do
          context 'but no Access-Control-Request-Method header is present' do
            it 'does not return any Access-Control headers' do
              response = make_preflight_request_with_origin 'http://wildcarded.inblue.net', nil, authed_headers
              expect(response['Access-Control']).to be_nil
            end
          end

          context 'and the Access-Control-Request-Method header is present' do
            it 'returns a 200 code and does not process the original request' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response.code).to eq('200')
              expect(response.body).to eq('')
            end

            it 'sets the Content-Type: text/plain header' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response.code).to eq('200')
              expect(response.body).to eq('')
              expect(response['Content-Type']).to eq('text/plain')
            end

            it 'should return a Vary: Origin header to ensure response is not cached for different origins' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Vary']).to eq('Origin')
            end

            it 'returns an Access-Control-Allow-Origin header containing the requested origin domain' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Access-Control-Allow-Origin']).to eq('http://bar.baz.inblue.net')
            end

            it 'allows credentials to be supplied' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Access-Control-Allow-Credentials']).to eq('true')
            end

            it 'returns the valid request methods in the Access-Control-Allow-Methods header' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Access-Control-Allow-Methods'].split(',')).to contain_exactly(
                'PUT', 'POST', 'DELETE', 'GET'
              )
            end

            it 'returns a max-age header with a large value (since these headers rarely change' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Access-Control-Max-Age'].to_i).to be > 600
            end

            it 'allows custom headers to be returned' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Access-Control-Expose-Headers'].split(',')).
                to contain_exactly('x-cf-warnings', 'x-app-staging-log', 'range', 'location', ::VCAP::Request::HEADER_NAME.downcase)
            end

            it 'allows needed request headers to be included' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Access-Control-Allow-Headers'].split(',')).to contain_exactly(
                'origin',
                'content-type',
                'authorization'
              )
            end

            context 'when the request asks to allow additional request headers' do
              let(:extra_headers) { { 'Access-Control-Request-Headers' => 'foo, bar, baz, Authorization' } }
              it 'allows that by adding them to the Allow-Headers list' do
                response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers.merge(extra_headers)
                expect(response['Access-Control-Allow-Headers'].split(',')).to contain_exactly(
                  'origin',
                  'content-type',
                  'authorization',
                  'foo', 'bar', 'baz'
                )
              end
            end
          end
        end
      end

      describe 'a simple request or actual request' do
        context 'and the origin is not in the whitelist' do
          it 'does not return any Access-Control headers' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://corblimey.com' }))
            expect(response.code).to eq('200')
            expect(response['Access-Control']).to be_nil
          end

          it 'delegates to the initial request' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://corblimey.com' }))
            expect(response.code).to eq('200')
            expect(response.json_body).to be_a(Hash)
          end
        end

        context 'and the origin is a subset of a domain in the whitelist, but does not match' do
          it 'does not return any Access-Control headers' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://talkoncorners.com.extra' }))
            expect(response['Access-Control']).to be_nil
          end

          it 'delegates to the initial request' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://talkoncorners.com.extra' }))
            expect(response.code).to eq('200')
            expect(response.json_body).to be_a(Hash)
          end
        end

        context 'and the origin matches an entry in the whitelist' do
          it 'delegates to the initial request' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://foo.inblue.net' }))
            expect(response.code).to eq('200')
            expect(response.json_body).to be_a(Hash)
          end

          it 'returns an Access-Control-Allow-Origin header containing the requested origin domain' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://foo.inblue.net' }))
            expect(response.code).to eq('200')
            expect(response['Access-Control-Allow-Origin']).to eq('http://foo.inblue.net')
          end

          it 'allows credentials to be supplied' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://foo.inblue.net' }))
            expect(response.code).to eq('200')
            expect(response['Access-Control-Allow-Credentials']).to eq('true')
          end

          it 'allows custom headers to be returned' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://foo.inblue.net' }))
            expect(response.code).to eq('200')
            expect(response['Access-Control-Expose-Headers'].split(',')).
              to contain_exactly('x-cf-warnings', 'x-app-staging-log', 'range', 'location', ::VCAP::Request::HEADER_NAME.downcase)
          end
        end
      end
    end
  end

  describe 'v2 sinatra app' do
    let(:test_path) { '/v2/info' }

    context 'when the Origin header is not present' do
      it 'does not return any Access-Control headers (the request is not a CORS request)' do
        response = make_get_request(test_path, authed_headers)
        expect(response.code).to eq('200')
        expect(response['Access-Control']).to be_nil
      end

      it 'delegates to the initial request' do
        response = make_get_request(test_path, authed_headers)
        expect(response.code).to eq('200')
        expect(response.json_body).to be_a(Hash)
      end
    end

    context 'when the Origin header is present' do
      describe 'a preflight request' do
        def make_preflight_request_with_origin(origin, method=nil, extra_headers={})
          headers = {}
          headers = headers.merge({ 'Origin' => origin })
          headers = headers.merge({ 'Access-Control-Request-Method' => method }) unless method.nil?
          headers = headers.merge(extra_headers)

          make_options_request(test_path, headers)
        end

        context 'and the origin is not in the whitelist' do
          it 'does not return any Access-Control headers' do
            response = make_preflight_request_with_origin 'http://corblimey.com', 'GET', authed_headers
            expect(response['Access-Control']).to be_nil
          end

          it 'delegates to the initial request ( there is no options method for /v2/info so we get a 404 )' do
            response = make_preflight_request_with_origin 'http://corblimey.com', 'GET', authed_headers
            expect(response.code).to eq('404')
          end
        end

        context 'and the origin is a subset of a domain in the whitelist, but does not match' do
          it 'does not return any Access-Control headers' do
            response = make_preflight_request_with_origin 'http://talkoncorners.com.extra', 'GET', authed_headers
            expect(response['Access-Control']).to be_nil
          end

          it 'delegates to the initial request ( there is no options method for /v2/info so we get a 404 )' do
            response = make_preflight_request_with_origin 'http://talkoncorners.com.extra', 'GET', authed_headers
            expect(response.code).to eq('404')
          end
        end

        context 'and the origin matches a domain in the whitelist' do
          context 'but no Access-Control-Request-Method header is present' do
            it 'does not return any Access-Control headers' do
              response = make_preflight_request_with_origin 'http://wildcarded.inblue.net', nil, authed_headers
              expect(response['Access-Control']).to be_nil
            end
          end

          context 'and the Access-Control-Request-Method header is present' do
            it 'returns a 200 code and does not process the original request' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response.code).to eq('200')
              expect(response.body).to eq('')
            end

            it 'sets the Content-Type: text/plain header' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response.code).to eq('200')
              expect(response.body).to eq('')
              expect(response['Content-Type']).to eq('text/plain')
            end

            it 'should return a Vary: Origin header to ensure response is not cached for different origins' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Vary']).to eq('Origin')
            end

            it 'returns an Access-Control-Allow-Origin header containing the requested origin domain' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Access-Control-Allow-Origin']).to eq('http://bar.baz.inblue.net')
            end

            it 'allows credentials to be supplied' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Access-Control-Allow-Credentials']).to eq('true')
            end

            it 'returns the valid request methods in the Access-Control-Allow-Methods header' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Access-Control-Allow-Methods'].split(',')).to contain_exactly(
                'PUT', 'POST', 'DELETE', 'GET'
              )
            end

            it 'returns a max-age header with a large value (since these headers rarely change' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Access-Control-Max-Age'].to_i).to be > 600
            end

            it 'allows custom headers to be returned' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Access-Control-Expose-Headers'].split(',')).
                to contain_exactly('x-cf-warnings', 'x-app-staging-log', 'range', 'location', ::VCAP::Request::HEADER_NAME.downcase)
            end

            it 'allows needed request headers to be included' do
              response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers
              expect(response['Access-Control-Allow-Headers'].split(',')).to contain_exactly(
                'origin',
                'content-type',
                'authorization'
              )
            end

            context 'when the request asks to allow additional request headers' do
              let(:extra_headers) { { 'Access-Control-Request-Headers' => 'foo, bar, baz, Authorization' } }
              it 'allows that by adding them to the Allow-Headers list' do
                response = make_preflight_request_with_origin 'http://bar.baz.inblue.net', 'PUT', authed_headers.merge(extra_headers)
                expect(response['Access-Control-Allow-Headers'].split(',')).to contain_exactly(
                  'origin',
                  'content-type',
                  'authorization',
                  'foo', 'bar', 'baz'
                )
              end
            end
          end
        end
      end

      describe 'a simple request or actual request' do
        context 'and the origin is not in the whitelist' do
          it 'does not return any Access-Control headers' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://corblimey.com' }))
            expect(response.code).to eq('200')
            expect(response['Access-Control']).to be_nil
          end

          it 'delegates to the initial request' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://corblimey.com' }))
            expect(response.code).to eq('200')
            expect(response.json_body).to be_a(Hash)
          end
        end

        context 'and the origin is a subset of a domain in the whitelist, but does not match' do
          it 'does not return any Access-Control headers' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://talkoncorners.com.extra' }))
            expect(response['Access-Control']).to be_nil
          end

          it 'delegates to the initial request' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://talkoncorners.com.extra' }))
            expect(response.code).to eq('200')
            expect(response.json_body).to be_a(Hash)
          end
        end

        context 'and the origin matches an entry in the whitelist' do
          it 'delegates to the initial request' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://foo.inblue.net' }))
            expect(response.code).to eq('200')
            expect(response.json_body).to be_a(Hash)
          end

          it 'returns an Access-Control-Allow-Origin header containing the requested origin domain' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://foo.inblue.net' }))
            expect(response.code).to eq('200')
            expect(response['Access-Control-Allow-Origin']).to eq('http://foo.inblue.net')
          end

          it 'allows credentials to be supplied' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://foo.inblue.net' }))
            expect(response.code).to eq('200')
            expect(response['Access-Control-Allow-Credentials']).to eq('true')
          end

          it 'allows custom headers to be returned' do
            response = make_get_request(test_path, authed_headers.merge({ 'Origin' => 'http://foo.inblue.net' }))
            expect(response.code).to eq('200')
            expect(response['Access-Control-Expose-Headers'].split(',')).
              to contain_exactly('x-cf-warnings', 'x-app-staging-log', 'range', 'location', ::VCAP::Request::HEADER_NAME.downcase)
          end
        end
      end
    end
  end
end
