require 'spec_helper'
require 'request_logs'

module CloudFoundry
  module Middleware
    describe CefLogs do
      let(:middleware) { described_class.new(app, logger, '10.10.10.100') }
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:logger) { double('logger', info: nil) }
      let(:fake_request) do
        instance_double(
          ActionDispatch::Request,
          method:        'request_method',
          ip:            'ip',
          filtered_path: 'filtered_path',
          path:          'plain_path',
          headers:       { 'HTTP_X_FORWARDED_FOR' => 'forwarded_ip', },
          authorization: true
        )
      end
      let(:env) do
        {
          'cf.request_id'      => 'ID',
          'cf.user_guid'       => 'some-guid',
          'cf.user_name'       => 'zach-loves-cake',
          'HTTP_AUTHORIZATION' => 'bearer stubbed-user-and-id-token'
        }
      end

      describe 'logging' do
        before do
          allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
        end

        it 'returns the app response unaltered' do
          expect(middleware.call(env)).to eq([200, {}, 'a body'])
        end

        it 'logs in the expected format' do
          Timecop.freeze

          cef_version  = 0
          severity     = 0
          signature_id = 'request_method plain_path'
          name         = 'request_method plain_path'
          request_id   = 'ID'

          middleware.call(env)
          expect(logger).to have_received(:info).with(
            "CEF:#{cef_version}|cloud_foundry|cloud_controller_ng|#{VCAP::CloudController::Constants::API_VERSION}|" \
            "#{signature_id}|#{name}|" \
            "#{severity}|" \
            "rt=#{(Time.now.utc.to_f * 1000).to_i} " \
            'suser=zach-loves-cake suid=some-guid ' \
            'request=filtered_path ' \
            'requestMethod=request_method ' \
            'src=ip ' \
            'dst=10.10.10.100 ' \
            'cs1Label=userAuthenticationMechanism cs1=oauth-access-token ' \
            "cs2Label=vcapRequestId cs2=#{request_id} " \
            'cs3Label=result cs3=success ' \
            'cs4Label=httpStatusCode cs4=200 ' \
            'cs5Label=xForwardedFor cs5=forwarded_ip'
          )

          Timecop.return
        end

        context 'when using basic auth' do
          let(:env) { { 'HTTP_AUTHORIZATION' => 'basic dXNlcjpwYXNzd29yZA==' } }

          it 'includes the user info as basic auth' do
            middleware.call(env)

            expect(logger).to have_received(:info) do |log|
              expect(log).to include('cs1=basic-auth')
              expect(log).to include('suser=user')
            end
          end
        end

        context 'when using bearer auth' do
          let(:env) do
            {
              'cf.user_guid'       => 'some-guid',
              'cf.user_name'       => 'zach-loves-cake',
              'HTTP_AUTHORIZATION' => 'bearer stubbed-user-and-id-token'
            }
          end

          it 'includes the user info as basic auth' do
            middleware.call(env)

            expect(logger).to have_received(:info) do |log|
              expect(log).to include('cs1=oauth-access-token')
              expect(log).to include('suser=zach-loves-cake')
              expect(log).to include('suid=some-guid')
            end
          end
        end

        context 'when using no auth' do
          let(:env) { {} }
          before { allow(fake_request).to receive(:authorization).and_return(nil) }

          it 'includes the user info as no-auth auth' do
            middleware.call(env)

            expect(logger).to have_received(:info) do |log|
              expect(log).to include('cs1=no-auth')
            end
          end
        end
      end

      describe '#get_result' do
        it 'translates 1xx to info' do
          expect(middleware.get_result(134)).to eq('info')
        end

        it 'translates 2xx to success' do
          expect(middleware.get_result(234)).to eq('success')
        end

        it 'translates 3xx to redirect' do
          expect(middleware.get_result(334)).to eq('redirect')
        end

        it 'translates 4xx to clientError' do
          expect(middleware.get_result(434)).to eq('clientError')
        end

        it 'translates 5xx to serverError' do
          expect(middleware.get_result(534)).to eq('serverError')
        end
      end
    end
  end
end
