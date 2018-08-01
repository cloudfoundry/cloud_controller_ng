require 'spec_helper'
require 'request_logs'

module CloudFoundry
  module Middleware
    RSpec.describe CefLogs do
      subject(:middleware) { described_class.new(app, logger, '10.10.10.100') }
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:logger) { double('logger', info: nil) }
      let(:headers) { ActionDispatch::Http::Headers.new({ 'HTTP_X_FORWARDED_FOR' => 'forwarded_ip, another_forwarded_ip' }) }
      let(:fake_request) do
        instance_double(
          ActionDispatch::Request,
          method:        'request_method',
          ip:            'ip',
          filtered_path: 'filtered_path',
          path:          'plain_path',
          headers:       headers,
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

      before do
        allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
      end

      describe 'logging' do
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
            'src=forwarded_ip ' \
            'dst=10.10.10.100 ' \
            'cs1Label=userAuthenticationMechanism cs1=oauth-access-token ' \
            "cs2Label=vcapRequestId cs2=#{request_id} " \
            'cs3Label=result cs3=success ' \
            'cs4Label=httpStatusCode cs4=200 ' \
            'cs5Label=xForwardedFor cs5=forwarded_ip, another_forwarded_ip'
          )

          Timecop.return
        end

        context 'when HTTP_X_FORWARDED_FOR is not present' do
          let(:headers) { ActionDispatch::Http::Headers.new }

          it 'uses request.ip for src' do
            expect {
              middleware.call(env)
            }.not_to raise_error

            expect(logger).to have_received(:info).with(/src=ip/)
          end

          context 'when request.ip is an RFC1918 address' do
            let(:env) do
              {
                'cf.request_id'      => 'ID',
                'cf.user_guid'       => 'some-guid',
                'cf.user_name'       => 'zach-loves-cake',
                'HTTP_AUTHORIZATION' => 'bearer stubbed-user-and-id-token',
                'REMOTE_ADDR'        => '10.0.0.1',
                'REQUEST_METHOD'     => 'GET',
              }
            end
            let!(:fake_request) do
              ActionDispatch::Request.new(env)
            end

            it 'uses REMOTE_ADDR' do
              middleware.call(env)
              expect(logger).to have_received(:info).with(/src=10.0.0.1/)
            end
          end
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

      describe 'CEF encoding' do
        # see https://kc.mcafee.com/resources/sites/MCAFEE/content/live/CORP_KNOWLEDGEBASE/78000/KB78712/en_US/CEF_White_Paper_20100722.pdf
        # Character Encoding section

        before do
          Timecop.freeze
        end

        after do
          Timecop.return
        end

        it 'escapes "|" in the prefix' do
          allow(fake_request).to receive(:method).and_return('a|b')
          allow(fake_request).to receive(:path).and_return('pa|th')

          middleware.call(env)

          expect(logger).to have_received(:info).with(
            "CEF:0|cloud_foundry|cloud_controller_ng|#{VCAP::CloudController::Constants::API_VERSION}|" \
            'a\|b pa\|th|a\|b pa\|th|' \
            '0|' \
            "rt=#{(Time.now.utc.to_f * 1000).to_i} " \
            'suser=zach-loves-cake suid=some-guid ' \
            'request=filtered_path ' \
            'requestMethod=a|b ' \
            'src=forwarded_ip ' \
            'dst=10.10.10.100 ' \
            'cs1Label=userAuthenticationMechanism cs1=oauth-access-token ' \
            'cs2Label=vcapRequestId cs2=ID ' \
            'cs3Label=result cs3=success ' \
            'cs4Label=httpStatusCode cs4=200 ' \
            'cs5Label=xForwardedFor cs5=forwarded_ip, another_forwarded_ip'
          )
        end

        it 'escapes "\" in the prefix' do
          allow(fake_request).to receive(:method).and_return('a\b')
          allow(fake_request).to receive(:path).and_return('pa\th')

          middleware.call(env)

          expect(logger).to have_received(:info).with(
            "CEF:0|cloud_foundry|cloud_controller_ng|#{VCAP::CloudController::Constants::API_VERSION}|" \
            'a\\\\b pa\\\\th|a\\\\b pa\\\\th|' \
            '0|' \
            "rt=#{(Time.now.utc.to_f * 1000).to_i} " \
            'suser=zach-loves-cake suid=some-guid ' \
            'request=filtered_path ' \
            'requestMethod=a\\\\b ' \
            'src=forwarded_ip ' \
            'dst=10.10.10.100 ' \
            'cs1Label=userAuthenticationMechanism cs1=oauth-access-token ' \
            'cs2Label=vcapRequestId cs2=ID ' \
            'cs3Label=result cs3=success ' \
            'cs4Label=httpStatusCode cs4=200 ' \
            'cs5Label=xForwardedFor cs5=forwarded_ip, another_forwarded_ip'
          )
        end

        it 'escapes "\" in the extensions' do
          env['cf.user_name'] = 'pot\ato'

          middleware.call(env)

          expect(logger).to have_received(:info).with(
            "CEF:0|cloud_foundry|cloud_controller_ng|#{VCAP::CloudController::Constants::API_VERSION}|" \
            'request_method plain_path|request_method plain_path|' \
            '0|' \
            "rt=#{(Time.now.utc.to_f * 1000).to_i} " \
            'suser=pot\\\\ato suid=some-guid ' \
            'request=filtered_path ' \
            'requestMethod=request_method ' \
            'src=forwarded_ip ' \
            'dst=10.10.10.100 ' \
            'cs1Label=userAuthenticationMechanism cs1=oauth-access-token ' \
            'cs2Label=vcapRequestId cs2=ID ' \
            'cs3Label=result cs3=success ' \
            'cs4Label=httpStatusCode cs4=200 ' \
            'cs5Label=xForwardedFor cs5=forwarded_ip, another_forwarded_ip'
          )
        end

        it 'escapes "=" in the extensions' do
          env['cf.user_name'] = 'pot=ato'

          middleware.call(env)

          expect(logger).to have_received(:info).with(
            "CEF:0|cloud_foundry|cloud_controller_ng|#{VCAP::CloudController::Constants::API_VERSION}|" \
            'request_method plain_path|request_method plain_path|' \
            '0|' \
            "rt=#{(Time.now.utc.to_f * 1000).to_i} " \
            'suser=pot\=ato suid=some-guid ' \
            'request=filtered_path ' \
            'requestMethod=request_method ' \
            'src=forwarded_ip ' \
            'dst=10.10.10.100 ' \
            'cs1Label=userAuthenticationMechanism cs1=oauth-access-token ' \
            'cs2Label=vcapRequestId cs2=ID ' \
            'cs3Label=result cs3=success ' \
            'cs4Label=httpStatusCode cs4=200 ' \
            'cs5Label=xForwardedFor cs5=forwarded_ip, another_forwarded_ip'
          )
        end
      end
    end
  end
end
