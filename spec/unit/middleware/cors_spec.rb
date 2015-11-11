require 'spec_helper'
require 'cors'

module CloudFoundry
  module Middleware
    describe Cors do
      let(:allowed_domains) { ['http://*.inblue.net', 'http://talkoncorners.com', 'http://borrowedheaven.org'] }
      let(:middleware) { described_class.new(app, allowed_domains) }
      let(:app) { double(:app, call: [123, {}, 'a body']) }

      context 'when the Origin header is not present' do
        it 'does not return any Access-Control headers (the request is not a CORS request)' do
          _, headers, _ = middleware.call({})
          expect(headers['Access-Control']).to be_nil
        end

        it 'delegates to the initial request' do
          status, _, body = middleware.call({})
          expect(status).to eq(123)
          expect(body).to eq('a body')
        end
      end

      context 'when the Origin header is present' do
        describe 'preflight request' do
          context 'and the origin is not in the whitelist' do
            let(:origin) { 'http://corblimey.com' }

            it 'does not return any Access-Control headers' do
              request_headers       = {
                'HTTP_ORIGIN'                        => origin,
                'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'GET',
                'REQUEST_METHOD'                     => 'OPTIONS'
              }
              _, headers, _ = middleware.call(request_headers)

              expect(headers['Access-Control']).to be_nil
            end

            it 'delegates to the initial request' do
              request_headers       = {
                'HTTP_ORIGIN'                        => origin,
                'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'GET',
                'REQUEST_METHOD'                     => 'OPTIONS'
              }
              status, _, body = middleware.call(request_headers)

              expect(status).to eq(123)
              expect(body).to eq('a body')
            end
          end

          context 'and the origin is a subset of a domain in the whitelist, but does not match' do
            let(:origin) { 'http://talkoncorners.com.extra' }

            it 'does not return any Access-Control headers' do
              request_headers       = {
                'HTTP_ORIGIN'                        => origin,
                'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'GET',
                'REQUEST_METHOD'                     => 'OPTIONS'
              }
              _, headers, _ = middleware.call(request_headers)

              expect(headers['Access-Control']).to be_nil
            end

            it 'delegates to the initial request' do
              request_headers       = {
                'HTTP_ORIGIN'                        => origin,
                'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'GET',
                'REQUEST_METHOD'                     => 'OPTIONS'
              }
              status, _, body = middleware.call(request_headers)

              expect(status).to eq(123)
              expect(body).to eq('a body')
            end
          end

          context 'and the origin matches a domain in the whitelist' do
            let(:origin) { 'http://wildcarded.inblue.net' }

            context 'but no Access-Control-Request-Method header is present' do
              it 'does not return any Access-Control headers' do
                request_headers       = {
                  'HTTP_ORIGIN'    => origin,
                  'REQUEST_METHOD' => 'OPTIONS'
                }
                _, headers, _ = middleware.call(request_headers)

                expect(headers['Access-Control']).to be_nil
              end

              it 'delegates to the initial request' do
                request_headers       = {
                  'HTTP_ORIGIN'    => origin,
                  'REQUEST_METHOD' => 'OPTIONS'
                }
                status, _, body = middleware.call(request_headers)

                expect(status).to eq(123)
                expect(body).to eq('a body')
              end
            end

            context 'and the Access-Control-Request-Method header is present' do
              let(:request_headers) do
                {
                  'HTTP_ORIGIN'                        => origin,
                  'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'GET',
                  'REQUEST_METHOD'                     => 'OPTIONS'
                }
              end

              it 'returns a 200 code and does not process the original request' do
                status, _, body = middleware.call(request_headers)

                expect(status).to eq(200)
                expect(body).to eq('')
              end

              it 'sets the Content-Type: text/plain header' do
                _, headers, _ = middleware.call(request_headers)
                expect(headers['Content-Type']).to eq('text/plain')
              end

              it 'should return a Vary: Origin header to ensure response is not cached for different origins' do
                _, headers, _ = middleware.call(request_headers)
                expect(headers['Vary']).to eq('Origin')
              end

              it 'returns an Access-Control-Allow-Origin header containing the requested origin domain' do
                _, headers, _ = middleware.call(request_headers)
                expect(headers['Access-Control-Allow-Origin']).to eq('http://wildcarded.inblue.net')
              end

              it 'allows credentials to be supplied' do
                _, headers, _ = middleware.call(request_headers)
                expect(headers['Access-Control-Allow-Credentials']).to eq('true')
              end

              it 'returns the valid request methods in the Access-Control-Allow-Methods header' do
                _, headers, _ = middleware.call(request_headers)
                expect(headers['Access-Control-Allow-Methods'].split(',')).to contain_exactly(
                    'PUT', 'POST', 'DELETE', 'GET'
                  )
              end

              it 'returns a max-age header with a large value (since these headers rarely change' do
                _, headers, _ = middleware.call(request_headers)
                expect(headers['Access-Control-Max-Age'].to_i).to be > 600
              end

              it 'allows custom headers to be returned' do
                _, headers, _ = middleware.call(request_headers)
                expect(headers['Access-Control-Expose-Headers'].split(',')).
                  to contain_exactly('x-cf-warnings', 'x-app-staging-log', 'range', 'location', ::VCAP::Request::HEADER_NAME.downcase)
              end

              it 'allows needed request headers to be included' do
                _, headers, _ = middleware.call(request_headers)
                expect(headers['Access-Control-Allow-Headers'].split(',')).to contain_exactly(
                    'origin',
                    'content-type',
                    'authorization'
                  )
              end

              it 'returns Vary: Origin header' do
                _, headers, _ = middleware.call(request_headers)
                expect(headers['Vary'].split(',')).to contain_exactly('Origin')
              end

              context 'when the request asks to allow additional request headers' do
                let(:extra_headers) { { 'HTTP_ACCESS_CONTROL_REQUEST_HEADERS' => 'foo, bar, baz, Authorization' } }
                it 'allows that by adding them to the Allow-Headers list' do
                  _, headers, _ = middleware.call(request_headers.merge(extra_headers))
                  expect(headers['Access-Control-Allow-Headers'].split(',')).to contain_exactly(
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
            let(:origin) { 'http://corblimey.com' }

            it 'does not return any Access-Control headers' do
              request_headers = {
                'HTTP_ORIGIN'    => origin,
                'REQUEST_METHOD' => 'GET'
              }

              _, headers, _ = middleware.call(request_headers)

              expect(headers['Access-Control']).to be_nil
            end

            it 'delegates to the initial request' do
              request_headers = {
                'HTTP_ORIGIN'    => origin,
                'REQUEST_METHOD' => 'GET'
              }

              status, _, body = middleware.call(request_headers)

              expect(status).to eq(123)
              expect(body).to eq('a body')
            end
          end

          context 'and the origin is a subset of a domain in the whitelist, but does not match' do
            let(:origin) { 'http://talkoncorners.com.extra' }

            it 'does not return any Access-Control headers' do
              request_headers = {
                'HTTP_ORIGIN'    => origin,
                'REQUEST_METHOD' => 'GET'
              }

              _, headers, _ = middleware.call(request_headers)

              expect(headers['Access-Control']).to be_nil
            end

            it 'delegates to the initial request' do
              request_headers = {
                'HTTP_ORIGIN'    => origin,
                'REQUEST_METHOD' => 'GET'
              }

              status, _, body = middleware.call(request_headers)

              expect(status).to eq(123)
              expect(body).to eq('a body')
            end
          end

          context 'and the origin matches an entry in the whitelist' do
            let(:origin) { 'http://foo.inblue.net' }

            it 'delegates to the initial request' do
              request_headers = {
                'HTTP_ORIGIN'    => origin,
                'REQUEST_METHOD' => 'GET'
              }

              status, _, body = middleware.call(request_headers)

              expect(status).to eq(123)
              expect(body).to eq('a body')
            end

            it 'returns an Access-Control-Allow-Origin header containing the requested origin domain' do
              request_headers = {
                'HTTP_ORIGIN'    => origin,
                'REQUEST_METHOD' => 'GET'
              }

              _, headers, _ = middleware.call(request_headers)

              expect(headers['Access-Control-Allow-Origin']).to eq('http://foo.inblue.net')
            end

            it 'allows credentials to be supplied' do
              request_headers = {
                'HTTP_ORIGIN'    => origin,
                'REQUEST_METHOD' => 'GET'
              }

              _, headers, _ = middleware.call(request_headers)

              expect(headers['Access-Control-Allow-Credentials']).to eq('true')
            end

            it 'allows custom headers to be returned' do
              request_headers = {
                'HTTP_ORIGIN'    => origin,
                'REQUEST_METHOD' => 'GET'
              }

              _, headers, _ = middleware.call(request_headers)

              expect(headers['Access-Control-Expose-Headers'].split(',')).
                to contain_exactly('x-cf-warnings', 'x-app-staging-log', 'range', 'location', ::VCAP::Request::HEADER_NAME.downcase)
            end

            describe 'Vary header' do
              it 'includes Origin' do
                request_headers = {
                  'HTTP_ORIGIN'    => origin,
                  'REQUEST_METHOD' => 'GET'
                }

                _, headers, _ = middleware.call(request_headers)
                expect(headers['Vary'].split(',')).to include('Origin')
              end

              context 'when there are other values included' do
                before do
                  allow(app).to receive(:call).and_return([123, { 'Vary' => 'Pre-existing' }, 'a body'])
                end

                it 'maintains them' do
                  request_headers = {
                    'HTTP_ORIGIN'    => origin,
                    'REQUEST_METHOD' => 'GET'
                  }

                  _, headers, _ = middleware.call(request_headers)
                  expect(headers['Vary'].split(',')).to contain_exactly('Origin', 'Pre-existing')
                end
              end
            end
          end
        end
      end
    end
  end
end
