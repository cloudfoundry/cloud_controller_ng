require 'spec_helper'

module VCAP::CloudController
  describe FrontController do
    let(:fake_logger) { double(Steno::Logger, info: nil) }
    let(:request_metrics) { double(:request_metrics, start_request: nil, complete_request: nil) }

    before :all do
      FrontController.get '/test_front_endpoint' do
        'test'
      end

      FrontController.options '/test_front_endpoint' do
        status 201
        'options'
      end
    end

    describe 'setting the locale' do
      before do
        @original_default_locale = I18n.default_locale
        @original_locale         = I18n.locale

        I18n.default_locale = :metropolis
        I18n.locale         = :metropolis
      end

      after do
        I18n.default_locale = @original_default_locale
        I18n.locale         = @original_locale
      end

      context 'When the Accept-Language header is set' do
        it 'sets the locale based on the Accept-Language header' do
          get '/test_front_endpoint', '', { 'HTTP_ACCEPT_LANGUAGE' => 'gotham_City' }
          expect(I18n.locale).to eq(:gotham_City)
        end
      end

      context 'when the Accept-Language header is not set' do
        it 'maintains the default locale' do
          get '/test_front_endpoint', '', {}
          expect(I18n.locale).to eq(:metropolis)
        end
      end
    end

    describe 'logging' do
      let(:user) { User.make }

      context 'get request' do
        before do
          allow(Steno).to receive(:logger).with(anything).and_return(fake_logger)
        end

        it 'logs request id and status code for all requests' do
          get '/test_front_endpoint', '', {}
          request_id = last_response.headers['X-Vcap-Request-Id']
          request_status = last_response.status.to_s
          expect(fake_logger).to have_received(:info).with("Completed request, Vcap-Request-Id: #{request_id}, Status: #{request_status}")
        end

        it 'logs request id and user guid for all requests' do
          get '/test_front_endpoint', '', headers_for(user)
          request_id = last_response.headers['X-Vcap-Request-Id']
          expect(fake_logger).to have_received(:info).with("Started request, Vcap-Request-Id: #{request_id}, User: #{user.guid}")
        end
      end
    end

    describe 'using a cross-origin request' do
      before do
        decoder = double(:decoder, configure: nil)
        allow(::VCAP::CloudController::Security::SecurityContextConfigurer).to receive(:new).and_return(decoder)
        allow(::VCAP::CloudController::SecurityContext).to receive(:current_user).and_return(User.make)
      end

      context 'when the Origin header is not present' do
        it 'does not return any Access-Control headers (the request is not a CORS request)' do
          get '/test_front_endpoint', '', {}
          expect(last_response.headers.keep_if { |k, _| k.start_with? 'Access-Control' }).to be_empty
        end

        it 'delegates to the initial request' do
          get '/test_front_endpoint', '', {}
          expect(last_response.body).to eq('test')
        end
      end

      context 'when the Origin header is present' do
        let(:config) do
          {
            allowed_cors_domains: ['https://talkoncorners.com', 'http://*.inblue.net', 'http://borrowedheaven.org']
          }
        end

        def app
          described_class.new(config, nil, request_metrics)
        end

        describe 'a preflight request' do
          def make_request_with_origin(origin, method=nil, extra_headers={})
            headers = { 'HTTP_ORIGIN' => origin }
            headers = headers.merge('HTTP_ACCESS_CONTROL_REQUEST_METHOD' => method) unless method.nil?
            headers = headers.merge(extra_headers)
            options '/test_front_endpoint', '', headers
          end

          context 'and the origin is not in the whitelist' do
            it 'does not return any Access-Control headers' do
              make_request_with_origin 'http://corblimey.com', 'PUT'
              expect(last_response.headers.keep_if { |k, _| k.start_with? 'Access-Control' }).to be_empty
            end
          end

          context 'and the origin is a subset of a domain in the whitelist, but does not match' do
            it 'does not return any Access-Control headers' do
              make_request_with_origin 'http://talkoncorners.com.extra'
              expect(last_response.headers.keep_if { |k, _| k.start_with? 'Access-Control' }).to be_empty
            end

            it 'delegates to the initial request' do
              get '/test_front_endpoint', '', {}
              expect(last_response.body).to eq('test')
            end
          end

          context 'and the origin matches a domain in the whitelist' do
            context 'but no Access-Control-Request-Method header is present' do
              it 'does not return any Access-Control headers' do
                make_request_with_origin 'http://wildcarded.inblue.net'
                expect(last_response.headers.keep_if { |k, _| k.start_with? 'Access-Control' }).to be_empty
              end

              it 'delegates to the original request' do
                options '/test_front_endpoint', '', {}
                expect(last_response.status).to eq(201)
                expect(last_response.body).to eq('options')
              end
            end

            context 'and the Access-Control-Request-Method header is present' do
              let(:extra_headers) { {} }
              before do
                make_request_with_origin 'http://bar.baz.inblue.net', 'PUT', extra_headers
              end

              it 'returns a 200 code and does not process the original request' do
                expect(last_response.body).to eq('')
                expect(last_response.status).to eq(200)
              end

              it 'should return a Vary: Origin header to ensure response is not cached for different origins' do
                expect(last_response.headers['Vary']).to eq('Origin')
              end

              it 'returns an Access-Control-Allow-Origin header containing the requested origin domain' do
                expect(last_response.headers['Access-Control-Allow-Origin']).to eq('http://bar.baz.inblue.net')
              end

              it 'allows credentials to be supplied' do
                expect(last_response.headers['Access-Control-Allow-Credentials']).to eq('true')
              end

              it 'returns the valid request methods in the Access-Control-Allow-Methods header' do
                expect(last_response.headers['Access-Control-Allow-Methods'].split(',')).to contain_exactly(
                  'PUT', 'POST', 'DELETE', 'GET'
                )
              end

              it 'returns a max-age header with a large value (since these headers rarely change' do
                expect(last_response.headers['Access-Control-Max-Age'].to_i).to be > 600
              end

              it 'allows custom headers to be returned' do
                expect(last_response.headers['Access-Control-Expose-Headers'].split(',')).
                  to contain_exactly('x-cf-warnings', 'x-app-staging-log', 'range', 'location', ::VCAP::Request::HEADER_NAME.downcase)
              end

              it 'allows needed request headers to be included' do
                expect(last_response.headers['Access-Control-Allow-Headers'].split(',')).to contain_exactly(
                  'origin',
                  'content-type',
                  'authorization'
                )
              end

              context 'when the request asks to allow additional request headers' do
                let(:extra_headers) { { 'HTTP_ACCESS_CONTROL_REQUEST_HEADERS' => 'foo, bar, baz, Authorization' } }
                it 'allows that by adding them to the Allow-Headers list' do
                  expect(last_response.headers['Access-Control-Allow-Headers'].split(',')).to contain_exactly(
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
          def make_request_with_origin(origin)
            get '/test_front_endpoint', '', { 'HTTP_ORIGIN' => origin }
          end

          context 'and the origin is not in the whitelist' do
            it 'does not return any Access-Control headers' do
              make_request_with_origin 'http://corblimey.com'
              expect(last_response.headers.keep_if { |k, _| k.start_with? 'Access-Control' }).to be_empty
            end

            it 'delegates to the initial request' do
              get '/test_front_endpoint', '', {}
              expect(last_response.body).to eq('test')
            end
          end

          context 'and the origin is a subset of a domain in the whitelist, but does not match' do
            it 'does not return any Access-Control headers' do
              make_request_with_origin 'http://talkoncorners.com.extra'
              expect(last_response.headers.keep_if { |k, _| k.start_with? 'Access-Control' }).to be_empty
            end

            it 'delegates to the initial request' do
              get '/test_front_endpoint', '', {}
              expect(last_response.body).to eq('test')
            end
          end

          context 'and the origin matches an entry in the whitelist' do
            before do
              make_request_with_origin 'http://foo.inblue.net'
            end

            it 'delegates to the initial request' do
              get '/test_front_endpoint', '', {}
              expect(last_response.body).to eq('test')
            end

            it 'returns an Access-Control-Allow-Origin header containing the requested origin domain' do
              expect(last_response.headers['Access-Control-Allow-Origin']).to eq('http://foo.inblue.net')
            end

            it 'allows credentials to be supplied' do
              expect(last_response.headers['Access-Control-Allow-Credentials']).to eq('true')
            end

            it 'allows custom headers to be returned' do
              expect(last_response.headers['Access-Control-Expose-Headers'].split(',')).
                to contain_exactly('x-cf-warnings', 'x-app-staging-log', 'range', 'location', ::VCAP::Request::HEADER_NAME.downcase)
            end
          end
        end
      end
    end

    describe 'validating the auth token' do
      let(:user_id) { Sham.guid }
      let(:token_info) { {} }

      let(:config) do
        {
          quota_definitions: [],
          uaa: { resource_id: 'cloud_controller' }
        }
      end
      let(:token_decoder) do
        token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])
        allow(token_decoder).to receive_messages(decode_token: token_info)
        token_decoder
      end

      def app
        described_class.new(TestConfig.config, token_decoder, request_metrics)
      end

      def make_request
        get '/test_front_endpoint', '', { 'HTTP_AUTHORIZATION' => 'bearer token' }
      end

      context 'when user_id is present' do
        before { token_info['user_id'] = user_id }

        it 'creates a user' do
          expect {
            make_request
          }.to change { VCAP::CloudController::User.count }.by(1)

          user = VCAP::CloudController::User.last
          expect(user.guid).to eq(user_id)
          expect(user.active).to be true
        end

        it 'sets security context to the user' do
          make_request
          expect(VCAP::CloudController::SecurityContext.current_user).to eq VCAP::CloudController::User.last
          expect(VCAP::CloudController::SecurityContext.token['user_id']).to eq user_id
        end
      end

      context 'when client_id is present' do
        before { token_info['client_id'] = user_id }

        it 'creates a user' do
          expect {
            make_request
          }.to change { VCAP::CloudController::User.count }.by(1)

          user = VCAP::CloudController::User.last
          expect(user.guid).to eq(user_id)
          expect(user.active).to be true
        end

        it 'sets security context to the user' do
          make_request
          expect(VCAP::CloudController::SecurityContext.current_user).to eq VCAP::CloudController::User.last
          expect(VCAP::CloudController::SecurityContext.token['client_id']).to eq user_id
        end
      end

      context 'when there is no user_id or client_id' do
        it 'does not create user' do
          expect { make_request }.to_not change { VCAP::CloudController::User.count }
        end

        it 'sets security context to be empty' do
          make_request
          expect(VCAP::CloudController::SecurityContext.current_user).to be_nil
          expect(VCAP::CloudController::SecurityContext.token).to be_nil
        end
      end
    end

    describe 'request metrics' do
      let(:app) { described_class.new(nil, token_decoder, request_metrics) }
      let(:token_decoder) { VCAP::UaaTokenDecoder.new({}) }

      before do
        allow(token_decoder).to receive_messages(decode_token: {})
      end

      it 'triggers metrics' do
        get '/test_front_endpoint', '', {}

        expect(request_metrics).to have_received(:start_request)
        expect(request_metrics).to have_received(:complete_request).with(200)
      end
    end
  end
end
