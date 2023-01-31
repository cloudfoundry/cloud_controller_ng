require 'spec_helper'
require 'cloud_controller/logs/request_logs'

module VCAP::CloudController::Logs
  RSpec.describe RequestLogs do
    let(:request_logs) { RequestLogs.new(logger) }
    let(:logger) { double('logger', info: nil) }
    let(:fake_ip) { 'ip' }
    let(:fake_fullpath) { 'fullpath' }
    let(:fake_request) { double('request', request_method: 'request_method', ip: fake_ip, filtered_path: 'filtered_path', fullpath: fake_fullpath) }
    let(:request_id) { 'ID' }
    let(:env) { { 'cf.user_guid' => 'user-guid' } }
    let(:status) { 200 }

    describe 'logging' do
      before do
        allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
      end

      context '#start_request' do
        it 'logs the start of the request' do
          request_logs.start_request(request_id, env)
          expect(logger).to have_received(:info).with(/Started.+user: user-guid.+with vcap-request-id: ID/)
        end

        context 'request to /healthz endpoint' do
          let(:fake_fullpath) { '/healthz' }

          it 'does not log the start of the request' do
            request_logs.start_request(request_id, env)
            expect(logger).not_to have_received(:info)
          end
        end
      end

      context '#complete_request' do
        context 'with a matching start request' do
          before do
            request_logs.instance_variable_set(:@incomplete_requests, { request_id => {} })
          end

          it 'logs the completion of the request' do
            request_logs.complete_request(request_id, status)
            expect(logger).to have_received(:info).with(/Completed 200 vcap-request-id: ID/)
          end
        end

        context 'without a matching start request' do
          it 'does not log the completion of the request' do
            request_logs.complete_request(request_id, status)
            expect(logger).not_to have_received(:info)
          end
        end
      end

      context 'anonymize_ips flag is true' do
        before do
          TestConfig.override(logging: { anonymize_ips: 'true' })
        end

        it 'logs non ip addresses in ip field unaltered' do
          request_logs.start_request(request_id, env)
          expect(logger).to have_received(:info).with(/ip: ip/)
        end
      end

      context 'request with ipv4 address' do
        let(:fake_ip) { '192.168.1.80' }

        context 'anonymize_ips flag is false' do
          it 'logs full ipv4 addresses' do
            request_logs.start_request(request_id, env)
            expect(logger).to have_received(:info).with(/ip: 192.168.1.80/)
          end
        end

        context 'anonymize_ips flag is true' do
          before do
            TestConfig.override(logging: { anonymize_ips: 'true' })
          end

          it 'logs anonymized ipv4 addresses' do
            request_logs.start_request(request_id, env)
            expect(logger).to have_received(:info).with(/ip: 192.168.1.0/)
          end
        end
      end

      context 'request with ipv6 address' do
        let(:fake_ip) { '2001:0db8:85a3:1234:0000:8a2e:0370:7334' }

        context 'anonymize_ips flag is false' do
          it 'logs canonical and unaltered ipv6 addresses' do
            request_logs.start_request(request_id, env)
            expect(logger).to have_received(:info).with(/ip: 2001:0db8:85a3:1234:0000:8a2e:0370:7334/)
          end
        end

        context 'anonymize_ips flag is true' do
          before do
            TestConfig.override(logging: { anonymize_ips: 'true' })
          end

          it 'logs canonical and anonymized ipv6 addresses' do
            request_logs.start_request(request_id, env)
            expect(logger).to have_received(:info).with(/ip: 2001:0db8:85a3:0000:0000:0000:0000:0000/)
          end
        end
      end

      context 'request with non canonical(shortened) ipv6 address' do
        let(:fake_ip) { '2001:db8:85a3:1234::370:0' }

        context 'anonymize_ips flag is false' do
          it 'logs canonical and unaltered ipv6 addresses' do
            request_logs.start_request(request_id, env)
            expect(logger).to have_received(:info).with(/ip: 2001:0db8:85a3:1234:0000:0000:0370:0000/)
          end
        end

        context 'anonymize_ips flag is true' do
          before do
            TestConfig.override(logging: { anonymize_ips: 'true' })
          end

          it 'logs canonical and anonymized ipv6 addresses' do
            request_logs.start_request(request_id, env)
            expect(logger).to have_received(:info).with(/ip: 2001:0db8:85a3:0000:0000:0000:0000:0000/)
          end
        end
      end
    end
  end
end
