require 'spec_helper'
require 'diego/client'

module Diego
  RSpec.describe Client do
    let(:bbs_domain) { 'bbs.example.com' }
    let(:bbs_port) { '4443' }
    let(:bbs_uri) { "https://#{bbs_domain}:#{bbs_port}" }
    let(:ca_cert_file) { File.join(Paths::FIXTURES, 'certs/bbs_ca.crt') }
    let(:client_cert_file) { File.join(Paths::FIXTURES, 'certs/bbs_client.crt') }
    let(:client_key_file) { File.join(Paths::FIXTURES, 'certs/bbs_client.key') }
    let(:bbs_ip_1) { '1.2.3.4' }
    let(:bbs_ip_2) { '5.6.7.8' }
    let(:logger) { instance_double(Steno::Logger) }

    subject(:client) do
      Client.new(url: bbs_uri, ca_cert_file: ca_cert_file, client_cert_file: client_cert_file, client_key_file: client_key_file,
                 connect_timeout: 10, send_timeout: 10, receive_timeout: 10)
    end
    before do
      allow(::Resolv).to receive(:getaddresses).with(bbs_domain).and_return([bbs_ip_1, bbs_ip_2])
      allow(Steno).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)
    end

    describe 'configuration' do
      it "should set ENV['PB_IGNORE_DEPRECATIONS'] to true" do
        # to supress warnings in stderr when BBS sends deprecated keys in responses
        ENV.delete('PB_IGNORE_DEPRECATIONS')
        expect { subject }.to change { ENV['PB_IGNORE_DEPRECATIONS'] }.from(nil).to('true')
      end
    end

    describe '#ping' do
      let(:response_body) { Bbs::Models::PingResponse.encode(Bbs::Models::PingResponse.new(available: true)).to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/ping").to_return(status: response_status, body: response_body)
      end

      it 'returns a ping response' do
        expect(client.ping.available).to be_truthy
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/ping")).to have_been_made.once
      end

      context 'when it does not return successfully' do
        let(:response_status) { 500 }
        let(:response_body) { 'Internal Server Error' }

        it 'raises' do
          expect { client.ping }.to raise_error(ResponseError, /status: 500, body: Internal Server Error/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/ping").to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect { client.ping }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when decoding the response fails' do
        let(:response_body) { 'potato' }

        it 'raises' do
          expect { client.ping }.to raise_error(DecodeError)
        end
      end
    end

    describe '#upsert_domain' do
      let(:response_body) { Bbs::Models::UpsertDomainResponse.encode(Bbs::Models::UpsertDomainResponse.new(error: nil)).to_s }
      let(:response_status) { 200 }
      let(:domain) { 'domain' }
      let(:ttl) { VCAP::CloudController::Diego::APP_LRP_DOMAIN_TTL }

      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/domains/upsert").to_return(status: response_status, body: response_body)
      end

      it 'returns a domain lifecycle response' do
        expected_domain_request = Bbs::Models::UpsertDomainRequest.new(ttl: 120, domain: 'domain')

        response = client.upsert_domain(domain: domain, ttl: ttl)

        expect(response.error).to be_nil
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/domains/upsert").with(
                 body: Bbs::Models::UpsertDomainRequest.encode(expected_domain_request).to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made.once
      end

      context 'when it does not return successfully' do
        let(:response_status) { 500 }
        let(:response_body) { 'Internal Server Error' }

        it 'raises' do
          expect { client.upsert_domain(domain: domain, ttl: ttl) }.to raise_error(ResponseError, /status: 500, body: Internal Server Error/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/domains/upsert").to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect { client.upsert_domain(domain: domain, ttl: ttl) }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when decoding the response fails' do
        let(:response_body) { 'potato' }

        it 'raises' do
          expect { client.upsert_domain(domain: domain, ttl: ttl) }.to raise_error(DecodeError)
        end
      end

      context 'when the domain cannot be encoded' do
        it 'raises' do
          expect { client.upsert_domain(domain: 4, ttl: ttl) }.to raise_error(EncodeError)
        end
      end
    end

    describe '#desire_task' do
      let(:response_body) { Bbs::Models::TaskLifecycleResponse.encode(Bbs::Models::TaskLifecycleResponse.new(error: nil)).to_s }
      let(:response_status) { 200 }
      let(:task_definition) { Bbs::Models::TaskDefinition.new }

      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/desire.r2").to_return(status: response_status, body: response_body)
      end

      it 'returns a task lifecycle response' do
        expected_task_request = Bbs::Models::DesireTaskRequest.new(task_definition: task_definition, task_guid: 'task_guid', domain: 'domain')

        response = client.desire_task(task_definition: task_definition, task_guid: 'task_guid', domain: 'domain')

        expect(response.error).to be_nil
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/desire.r2").with(
                 body: Bbs::Models::DesireTaskRequest.encode(expected_task_request).to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made.once
      end

      context 'when it does not return successfully' do
        let(:response_status) { 500 }
        let(:response_body) { 'Internal Server Error' }

        it 'raises' do
          expect {
            client.desire_task(task_definition: task_definition, task_guid: 'task_guid', domain: 'domain')
          }.to raise_error(ResponseError, /status: 500, body: Internal Server Error/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/desire.r2").to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect { client.desire_task(task_definition: task_definition, task_guid: 'task_guid', domain: 'domain') }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when decoding the response fails' do
        let(:response_body) { 'potato' }

        it 'raises' do
          expect { client.desire_task(task_definition: task_definition, task_guid: 'task_guid', domain: 'domain') }.to raise_error(DecodeError)
        end
      end

      context 'when the task cannot be encoded' do
        it 'raises' do
          expect { client.desire_task(task_definition: 4, task_guid: 'task_guid', domain: 'domain') }.to raise_error(EncodeError)
        end
      end
    end

    describe '#tasks' do
      let(:response_body) { Bbs::Models::TasksResponse.encode(Bbs::Models::TasksResponse.new(error: nil)).to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/list.r2").to_return(status: response_status, body: response_body)
      end

      it 'returns a tasks response' do
        response = client.tasks

        expected_request = Bbs::Models::TasksRequest.new

        expect(response.error).to be_nil
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/list.r2").with(
                 body: Bbs::Models::TasksRequest.encode(expected_request).to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made.once
      end

      describe 'filtering' do
        it 'filters by domain' do
          response = client.tasks(domain: 'some-domain')

          expected_request = Bbs::Models::TasksRequest.new(domain: 'some-domain')

          expect(response.error).to be_nil
          expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/list.r2").with(
                   body: Bbs::Models::TasksRequest.encode(expected_request).to_s,
                   headers: { 'Content-Type' => 'application/x-protobuf' }
          )).to have_been_made.once
        end

        it 'filters by cell_id' do
          response = client.tasks(cell_id: 'cell-id-thing')

          expected_request = Bbs::Models::TasksRequest.new(cell_id: 'cell-id-thing')

          expect(response.error).to be_nil
          expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/list.r2").with(
                   body: Bbs::Models::TasksRequest.encode(expected_request).to_s,
                   headers: { 'Content-Type' => 'application/x-protobuf' }
          )).to have_been_made.once
        end
      end

      context 'when it does not return successfully' do
        let(:response_status) { 500 }
        let(:response_body) { 'Internal Server Error' }

        it 'raises' do
          expect { client.tasks }.to raise_error(ResponseError, /status: 500, body: Internal Server Error/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/list.r2").to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect { client.tasks }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when decoding the response fails' do
        let(:response_body) { 'potato' }

        it 'raises' do
          expect { client.tasks }.to raise_error(DecodeError)
        end
      end

      context 'when encoding the request fails' do
        it 'raises' do
          expect { client.tasks(domain: 1) }.to raise_error(EncodeError)
        end
      end
    end

    describe '#task_by_guid' do
      let(:response_body) { Bbs::Models::TaskResponse.encode(Bbs::Models::TaskResponse.new(error: nil)).to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/get_by_task_guid.r2").to_return(status: response_status, body: response_body)
      end

      it 'returns a task response' do
        response = client.task_by_guid('some-guid')

        expected_request = Bbs::Models::TaskByGuidRequest.new(task_guid: 'some-guid')

        expect(response.error).to be_nil
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/get_by_task_guid.r2").with(
                 body: Bbs::Models::TaskByGuidRequest.encode(expected_request).to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made.once
      end

      context 'when it does not return successfully' do
        let(:response_status) { 500 }
        let(:response_body) { 'Internal Server Error' }

        it 'raises' do
          expect { client.task_by_guid('some-guid') }.to raise_error(ResponseError, /status: 500, body: Internal Server Error/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/get_by_task_guid.r2").to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect { client.task_by_guid('some-guid') }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when decoding the response fails' do
        let(:response_body) { 'potato' }

        it 'raises' do
          expect { client.task_by_guid('some-guid') }.to raise_error(DecodeError)
        end
      end

      context 'when encoding the request fails' do
        it 'raises' do
          expect { client.task_by_guid(51) }.to raise_error(EncodeError)
        end
      end
    end

    describe '#cancel_task' do
      let(:response_body) { Bbs::Models::TaskLifecycleResponse.encode(Bbs::Models::TaskLifecycleResponse.new(error: nil)).to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/cancel").to_return(status: response_status, body: response_body)
      end

      it 'returns a task lifecycle response' do
        expected_cancel_request = Bbs::Models::TaskGuidRequest.new(task_guid: 'some-guid')

        response = client.cancel_task('some-guid')

        expect(response.error).to be_nil
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/cancel").with(
                 body: Bbs::Models::TaskGuidRequest.encode(expected_cancel_request).to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made.once
      end

      context 'when it does not return successfully' do
        let(:response_status) { 500 }
        let(:response_body) { 'Internal Server Error' }

        it 'raises' do
          expect { client.cancel_task('some-guid') }.to raise_error(ResponseError, /status: 500, body: Internal Server Error/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/tasks/cancel").to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect { client.cancel_task('some-guid') }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when decoding the response fails' do
        let(:response_body) { 'potato' }

        it 'raises' do
          expect { client.cancel_task('some-guid') }.to raise_error(DecodeError)
        end
      end

      context 'when the task guid request cannot be encoded' do
        it 'raises' do
          expect { client.cancel_task(4) }.to raise_error(EncodeError)
        end
      end
    end

    describe '#desire_lrp' do
      let(:response_body) { Bbs::Models::DesiredLRPLifecycleResponse.encode(Bbs::Models::DesiredLRPLifecycleResponse.new(error: nil)).to_s }
      let(:response_status) { 200 }
      let(:lrp) { ::Diego::Bbs::Models::DesiredLRP.new }

      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrp/desire.r2").to_return(status: response_status, body: response_body)
      end

      it 'returns a Desired LRP Lifecycle Response' do
        expected_desire_lrp_request = Bbs::Models::DesireLRPRequest.new(desired_lrp: lrp)

        response = client.desire_lrp(lrp)
        expect(response).to be_a(Bbs::Models::DesiredLRPLifecycleResponse)
        expect(response.error).to be_nil
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrp/desire.r2").with(
                 body: Bbs::Models::DesireLRPRequest.encode(expected_desire_lrp_request).to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made.once
      end

      context 'when it does not return successfully' do
        let(:response_status) { 500 }
        let(:response_body) { 'Internal Server Error' }

        it 'raises' do
          expect { client.desire_lrp(lrp) }.to raise_error(ResponseError, /status: 500, body: Internal Server Error/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrp/desire.r2").to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect { client.desire_lrp(lrp) }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when decoding the response fails' do
        let(:response_body) { 'potato' }

        it 'raises' do
          expect { client.desire_lrp(lrp) }.to raise_error(DecodeError)
        end
      end

      context 'when the request cannot be encoded' do
        it 'raises' do
          expect { client.desire_lrp(4) }.to raise_error(EncodeError)
        end
      end
    end

    describe '#desired_lrp_by_process_guid' do
      let(:lrp) { ::Diego::Bbs::Models::DesiredLRP.new(process_guid: process_guid) }
      let(:response_body) { Bbs::Models::DesiredLRPResponse.encode(Bbs::Models::DesiredLRPResponse.new(error: nil, desired_lrp: lrp)).to_s }
      let(:response_status) { 200 }

      let(:process_guid) { 'process-guid' }

      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrps/get_by_process_guid.r2").to_return(status: response_status, body: response_body)
      end

      it 'returns a Desired LRP Response' do
        expected_request = Bbs::Models::DesiredLRPByProcessGuidRequest.new(process_guid: process_guid)

        response = client.desired_lrp_by_process_guid(process_guid)
        expect(response).to be_a(Bbs::Models::DesiredLRPResponse)
        expect(response.error).to be_nil
        expect(response.desired_lrp).to eq(lrp)
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrps/get_by_process_guid.r2").with(
                 body: Bbs::Models::DesiredLRPByProcessGuidRequest.encode(expected_request).to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made.once
      end

      context 'when it does not return successfully' do
        let(:response_status) { 500 }
        let(:response_body) { 'Internal Server Error' }

        it 'raises' do
          expect {
            client.desired_lrp_by_process_guid(process_guid)
          }.to raise_error(ResponseError, /status: 500, body: Internal Server Error/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrps/get_by_process_guid.r2").to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect { client.desired_lrp_by_process_guid(process_guid) }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when decoding the response fails' do
        let(:response_body) { 'potato' }

        it 'raises' do
          expect { client.desired_lrp_by_process_guid(process_guid) }.to raise_error(DecodeError)
        end
      end

      context 'when the request cannot be encoded' do
        it 'raises' do
          expect { client.desired_lrp_by_process_guid(4) }.to raise_error(EncodeError)
        end
      end
    end

    describe '#remove_desired_lrp' do
      let(:process_guid) { 'process-guid' }
      let(:response_body) { Bbs::Models::DesiredLRPLifecycleResponse.encode(Bbs::Models::DesiredLRPLifecycleResponse.new(error: nil)).to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrp/remove").to_return(status: response_status, body: response_body)
      end

      it 'returns a Desired LRP Lifecycle Response' do
        expected_request = Bbs::Models::RemoveDesiredLRPRequest.new(process_guid: process_guid)

        response = client.remove_desired_lrp(process_guid)
        expect(response).to be_a(Bbs::Models::DesiredLRPLifecycleResponse)
        expect(response.error).to be_nil
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrp/remove").with(
                 body: Bbs::Models::RemoveDesiredLRPRequest.encode(expected_request).to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made.once
      end

      context 'when it does not return successfully' do
        let(:response_status) { 500 }
        let(:response_body) { 'Internal Server Error' }

        it 'raises' do
          expect { client.remove_desired_lrp('some-guid') }.to raise_error(ResponseError, /status: 500, body: Internal Server Error/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrp/remove").to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect { client.remove_desired_lrp(process_guid) }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when decoding the response fails' do
        let(:response_body) { 'potato' }

        it 'raises' do
          expect { client.remove_desired_lrp(process_guid) }.to raise_error(DecodeError)
        end
      end

      context 'when the request cannot be encoded' do
        it 'raises' do
          expect { client.remove_desired_lrp(4) }.to raise_error(EncodeError)
        end
      end
    end

    describe '#retire_actual_lrp' do
      let(:actual_lrp_key) { Bbs::Models::ActualLRPKey.new(process_guid: 'process-guid', index: 1, domain: 'domain') }
      let(:response_body) { Bbs::Models::ActualLRPLifecycleResponse.encode(Bbs::Models::ActualLRPLifecycleResponse.new(error: nil)).to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/actual_lrps/retire").to_return(status: response_status, body: response_body)
      end

      it 'returns an Actual LRP Lifecycle Response' do
        expected_request = Bbs::Models::RetireActualLRPRequest.new(actual_lrp_key: actual_lrp_key)

        response = client.retire_actual_lrp(actual_lrp_key)
        expect(response).to be_a(Bbs::Models::ActualLRPLifecycleResponse)
        expect(response.error).to be_nil
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/actual_lrps/retire").with(
                 body: Bbs::Models::RetireActualLRPRequest.encode(expected_request).to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made.once
      end

      context 'when it does not return successfully' do
        let(:response_status) { 500 }
        let(:response_body) { 'Internal Server Error' }

        it 'raises' do
          expect {
            client.retire_actual_lrp(actual_lrp_key)
          }.to raise_error(ResponseError, /status: 500, body: Internal Server Error/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/actual_lrps/retire").to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect { client.retire_actual_lrp(actual_lrp_key) }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when decoding the response fails' do
        let(:response_body) { 'potato' }

        it 'raises' do
          expect { client.retire_actual_lrp(actual_lrp_key) }.to raise_error(DecodeError)
        end
      end

      context 'when the request cannot be encoded' do
        it 'raises' do
          expect { client.retire_actual_lrp(4) }.to raise_error(EncodeError)
        end
      end
    end

    describe '#update_desired_lrp' do
      let(:process_guid) { 'process-guid' }
      let(:lrp_update) { ::Diego::Bbs::Models::DesiredLRPUpdate.new(instances: 3) }

      let(:response_body) { Bbs::Models::DesiredLRPLifecycleResponse.encode(Bbs::Models::DesiredLRPLifecycleResponse.new(error: nil)).to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrp/update").to_return(status: response_status, body: response_body)
      end

      it 'returns a Desired LRP Lifecycle Response' do
        expected_request = Bbs::Models::UpdateDesiredLRPRequest.new(process_guid: process_guid, update: lrp_update)

        response = client.update_desired_lrp(process_guid, lrp_update)
        expect(response).to be_a(Bbs::Models::DesiredLRPLifecycleResponse)
        expect(response.error).to be_nil
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrp/update").with(
                 body: Bbs::Models::UpdateDesiredLRPRequest.encode(expected_request).to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made.once
      end

      context 'when it does not return successfully' do
        let(:response_status) { 500 }
        let(:response_body) { 'Internal Server Error' }

        it 'raises' do
          expect { client.update_desired_lrp(process_guid, lrp_update) }.to raise_error(ResponseError, /status: 500, body: Internal Server Error/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrp/update").to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect { client.update_desired_lrp(process_guid, lrp_update) }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when decoding the response fails' do
        let(:response_body) { 'potato' }

        it 'raises' do
          expect { client.update_desired_lrp(process_guid, lrp_update) }.to raise_error(DecodeError)
        end
      end

      context 'when the request cannot be encoded' do
        it 'raises' do
          expect { client.update_desired_lrp(4, lrp_update) }.to raise_error(EncodeError)
        end
      end
    end

    describe '#actual_lrps_by_process_guid' do
      let(:process_guid) { 'process-guid' }

      let(:response_body) do
        Bbs::Models::ActualLRPsResponse.encode(
          Bbs::Models::ActualLRPsResponse.new(error: nil, actual_lrps: actual_lrps)
        ).to_s
      end
      let(:actual_lrps) { [::Diego::Bbs::Models::ActualLRP.new] }
      let(:response_status) { 200 }
      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/actual_lrps/list").to_return(status: response_status, body: response_body)
      end

      it 'returns a LRP instances response' do
        expected_request = Bbs::Models::ActualLRPsRequest.new(process_guid: process_guid)

        response = client.actual_lrps_by_process_guid(process_guid)
        expect(response).to be_a(Bbs::Models::ActualLRPsResponse)
        expect(response.error).to be_nil
        expect(response.actual_lrps).to eq(actual_lrps)
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/actual_lrps/list").with(
                 body: Bbs::Models::ActualLRPsRequest.encode(expected_request).to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made.once
      end
    end

    describe '#desired_lrps_scheduling_infos' do
      let(:scheduling_infos) { [::Diego::Bbs::Models::DesiredLRPSchedulingInfo.new] }
      let(:response_body) {
        response = Bbs::Models::DesiredLRPSchedulingInfosResponse.new(error: nil, desired_lrp_scheduling_infos: scheduling_infos)
        Bbs::Models::DesiredLRPSchedulingInfosResponse.encode(response).to_s
      }
      let(:response_status) { 200 }
      let(:domain) { 'domain' }

      before do
        stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrp_scheduling_infos/list").to_return(status: response_status, body: response_body)
      end

      it 'returns a Desired LRP Scheduling Infos Response' do
        expected_request = Bbs::Models::DesiredLRPsRequest.new(domain: domain)

        response = client.desired_lrp_scheduling_infos(domain)
        expect(response).to be_a(Bbs::Models::DesiredLRPSchedulingInfosResponse)
        expect(response.error).to be_nil
        expect(response.desired_lrp_scheduling_infos).to eq(scheduling_infos)
        expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrp_scheduling_infos/list").with(
                 body: Bbs::Models::DesiredLRPsRequest.encode(expected_request).to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made.once
      end

      context 'when it does not return successfully' do
        let(:response_status) { 500 }
        let(:response_body) { 'Internal Server Error' }

        it 'raises' do
          expect {
            client.desired_lrp_scheduling_infos(domain)
          }.to raise_error(ResponseError, /status: 500, body: Internal Server Error/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/v1/desired_lrp_scheduling_infos/list").to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect {
            client.desired_lrp_scheduling_infos(domain)
          }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when decoding the response fails' do
        let(:response_body) { 'potato' }

        it 'raises' do
          expect { client.desired_lrp_scheduling_infos(domain) }.to raise_error(DecodeError)
        end
      end

      context 'when the request cannot be encoded' do
        it 'raises' do
          expect { client.desired_lrp_scheduling_infos(9) }.to raise_error(EncodeError)
        end
      end
    end

    describe '#request_with_error_handling' do
      let(:http_client) { Net::HTTP.new(bbs_domain, bbs_port) }

      before do
        allow(http_client).to receive(:ipaddr=).with(bbs_ip_1)
        allow(http_client).to receive(:ipaddr=).with(bbs_ip_2)
        allow(Net::HTTP).to receive(:new).and_return(http_client)
      end

      context 'when all requests fail' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/fake_path").to_raise(StandardError.new('error message'))
        end

        it 'makes three attempts for each IP before raising an error' do
          expect {
            client.request_with_error_handling(Net::HTTP::Post.new('/fake_path'))
          }.to raise_error(RequestError)
          expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/fake_path")).to have_been_made.times(6)
          expect(http_client).to have_received(:ipaddr=).with(bbs_ip_1).exactly(3).times
          expect(http_client).to have_received(:ipaddr=).with(bbs_ip_2).exactly(3).times
        end
      end

      context 'when the first request succeeds' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/fake_path").to_return(status: 200)
          allow_any_instance_of(Net::HTTP).to receive(:ipaddr=).with(bbs_ip_1)
        end

        it 'makes one attempt for the first IP' do
          client.request_with_error_handling(Net::HTTP::Post.new('/fake_path'))
          expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/fake_path")).to have_been_made.once
          expect(http_client).to have_received(:ipaddr=).with(bbs_ip_1).once
        end
      end

      context 'when the first four requests fail and the fifth succeeds' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/fake_path").
            to_raise(StandardError.new('error message')).times(4).then.
            to_return(status: 200)
        end

        it 'makes five attempts' do
          client.request_with_error_handling(Net::HTTP::Post.new('/fake_path'))
          expect(a_request(:post, "https://#{bbs_domain}:#{bbs_port}/fake_path")).to have_been_made.times(5)
          expect(http_client).to have_received(:ipaddr=).with(bbs_ip_1).exactly(3).times
          expect(http_client).to have_received(:ipaddr=).with(bbs_ip_2).twice
        end
      end

      context 'logging' do
        before do
          stub_request(:post, "https://#{bbs_domain}:#{bbs_port}/fake_path").
            to_raise(StandardError.new('error message')).then.
            to_return(status: 200)
        end

        it 'logs before each request and after each failed request' do
          client.request_with_error_handling(Net::HTTP::Post.new('/fake_path'))
          expect(logger).to have_received(:info).with(%r{attempt 1: trying bbs endpoint /fake_path on #{bbs_ip_1}}).once
          expect(logger).to have_received(:info).with(/attempt 1: failed to reach bbs server on #{bbs_ip_1}, removing from list/).once
          expect(logger).to have_received(:info).with(%r{attempt 1: trying bbs endpoint /fake_path on #{bbs_ip_2}}).once
        end
      end
    end
  end
end
