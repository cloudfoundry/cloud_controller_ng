require 'spec_helper'
require 'request_logs'

module CloudFoundry
  module Middleware
    RSpec.describe RequestLogs do
      let(:middleware) { RequestLogs.new(app, logger) }
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:logger) { double('logger', info: nil) }
      let(:fake_request) { double('request', request_method: 'request_method', ip: 'ip', filtered_path: 'filtered_path') }
      let(:env) { { 'cf.request_id' => 'ID', 'cf.user_guid' => 'user-guid' } }

      describe 'logging' do
        before do
          allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
        end

        it 'returns the app response unaltered' do
          expect(middleware.call(env)).to eq([200, {}, 'a body'])
        end

        it 'logs before calling the app' do
          middleware.call(env)
          expect(logger).to have_received(:info).with(/Started.+user: user-guid.+with vcap-request-id: ID/)
        end

        it 'logs after calling the app' do
          middleware.call(env)
          expect(logger).to have_received(:info).with(/Completed.+vcap-request-id: ID/)
        end

        context 'anonymize_ips flag is true' do
          before do
            TestConfig.override(logging: { anonymize_ips: 'true' })
          end

          it 'logs non ip adresses in ip field unaltered' do
            middleware.call(env)
            expect(logger).to have_received(:info).with(/ip: ip/)
          end
        end

        context 'request with ipv4 adress' do
          let(:fake_request) { double('request', request_method: 'request_method', ip: '192.168.1.80', filtered_path: 'filtered_path') }

          context 'anonymize_ips flag is false' do
            it 'logs full ipv4 adresses' do
              middleware.call(env)
              expect(logger).to have_received(:info).with(/ip: 192.168.1.80/)
            end
          end

          context 'anonymize_ips flag is true' do
            before do
              TestConfig.override(logging: { anonymize_ips: 'true' })
            end

            it 'logs anonymized ipv4 adresses' do
              middleware.call(env)
              expect(logger).to have_received(:info).with(/ip: 192.168.1.0/)
            end
          end
        end

        context 'request with ipv6 adress' do
          let(:fake_request) { double('request', request_method: 'request_method', ip: '2001:0db8:85a3:1234:0000:8a2e:0370:7334', filtered_path: 'filtered_path') }

          context 'anonymize_ips flag is false' do
            it 'logs canonical and unaltered ipv6 adresses' do
              middleware.call(env)
              expect(logger).to have_received(:info).with(/ip: 2001:0db8:85a3:1234:0000:8a2e:0370:7334/)
            end
          end

          context 'anonymize_ips flag is true' do
            before do
              TestConfig.override(logging: { anonymize_ips: 'true' })
            end

            it 'logs canonical and anonymized ipv6 adresses' do
              middleware.call(env)
              expect(logger).to have_received(:info).with(/ip: 2001:0db8:85a3:0000:0000:0000:0000:0000/)
            end
          end
        end

        context 'request with non canonical(shortened) ipv6 adress' do
          let(:fake_request) { double('request', request_method: 'request_method', ip: '2001:db8:85a3:1234::370:0', filtered_path: 'filtered_path') }

          context 'anonymize_ips flag is false' do
            it 'logs canonical and unaltered ipv6 adresses' do
              middleware.call(env)
              expect(logger).to have_received(:info).with(/ip: 2001:0db8:85a3:1234:0000:0000:0370:0000/)
            end
          end

          context 'anonymize_ips flag is true' do
            before do
              TestConfig.override(logging: { anonymize_ips: 'true' })
            end

            it 'logs canonical and anonymized ipv6 adresses' do
              middleware.call(env)
              expect(logger).to have_received(:info).with(/ip: 2001:0db8:85a3:0000:0000:0000:0000:0000/)
            end
          end
        end
      end
    end
  end
end
