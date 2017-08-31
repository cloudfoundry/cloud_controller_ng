require 'spec_helper'
require 'diego/client'

module Diego
  RSpec.describe Client do
    let(:bbs_url) { 'https://bbs.example.com:4443' }
    let(:ca_cert_file) { File.join(Paths::FIXTURES, 'certs/bbs_ca.crt') }
    let(:client_cert_file) { File.join(Paths::FIXTURES, 'certs/bbs_client.crt') }
    let(:client_key_file) { File.join(Paths::FIXTURES, 'certs/bbs_client.key') }

    subject(:client) do
      Client.new(url: bbs_url, ca_cert_file: ca_cert_file, client_cert_file: client_cert_file, client_key_file: client_key_file)
    end

    describe '#ping' do
      let(:response_body) { Bbs::Models::PingResponse.new(available: true).encode.to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/ping').to_return(status: response_status, body: response_body)
      end

      it 'returns a ping response' do
        expect(client.ping.available).to be_truthy
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/ping')).to have_been_made
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
          stub_request(:post, 'https://bbs.example.com:4443/v1/ping').to_raise(StandardError.new('error message'))
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
      let(:response_body) { Bbs::Models::UpsertDomainResponse.new(error: nil).encode.to_s }
      let(:response_status) { 200 }
      let(:domain) { 'domain' }
      let(:ttl) { 100 }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/domains/upsert').to_return(status: response_status, body: response_body)
      end

      it 'returns a domain lifecycle response' do
        expected_domain_request = Bbs::Models::UpsertDomainRequest.new(ttl: ttl, domain: domain)

        response = client.upsert_domain(domain: domain, ttl: ttl)

        expect(response.error).to be_nil
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/domains/upsert').with(
                 body: expected_domain_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
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
          stub_request(:post, 'https://bbs.example.com:4443/v1/domains/upsert').to_raise(StandardError.new('error message'))
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
      let(:response_body) { Bbs::Models::TaskLifecycleResponse.new(error: nil).encode.to_s }
      let(:response_status) { 200 }
      let(:task_definition) { Bbs::Models::TaskDefinition.new }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/tasks/desire.r2').to_return(status: response_status, body: response_body)
      end

      it 'returns a task lifecycle response' do
        expected_task_request = Bbs::Models::DesireTaskRequest.new(task_definition: task_definition, task_guid: 'task_guid', domain: 'domain')

        response = client.desire_task(task_definition: task_definition, task_guid: 'task_guid', domain: 'domain')

        expect(response.error).to be_nil
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/tasks/desire.r2').with(
                 body: expected_task_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
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
          stub_request(:post, 'https://bbs.example.com:4443/v1/tasks/desire.r2').to_raise(StandardError.new('error message'))
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
      let(:response_body) { Bbs::Models::TasksResponse.new(error: nil).encode.to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/tasks/list.r2').to_return(status: response_status, body: response_body)
      end

      it 'returns a tasks response' do
        response = client.tasks

        expected_request = Bbs::Models::TasksRequest.new

        expect(response.error).to be_nil
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/tasks/list.r2').with(
                 body: expected_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
      end

      describe 'filtering' do
        it 'filters by domain' do
          response = client.tasks(domain: 'some-domain')

          expected_request = Bbs::Models::TasksRequest.new(domain: 'some-domain')

          expect(response.error).to be_nil
          expect(a_request(:post, 'https://bbs.example.com:4443/v1/tasks/list.r2').with(
                   body: expected_request.encode.to_s,
                   headers: { 'Content-Type' => 'application/x-protobuf' }
          )).to have_been_made
        end

        it 'filters by cell_id' do
          response = client.tasks(cell_id: 'cell-id-thing')

          expected_request = Bbs::Models::TasksRequest.new(cell_id: 'cell-id-thing')

          expect(response.error).to be_nil
          expect(a_request(:post, 'https://bbs.example.com:4443/v1/tasks/list.r2').with(
                   body: expected_request.encode.to_s,
                   headers: { 'Content-Type' => 'application/x-protobuf' }
          )).to have_been_made
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
          stub_request(:post, 'https://bbs.example.com:4443/v1/tasks/list.r2').to_raise(StandardError.new('error message'))
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
      let(:response_body) { Bbs::Models::TaskResponse.new(error: nil).encode.to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/tasks/get_by_task_guid.r2').to_return(status: response_status, body: response_body)
      end

      it 'returns a task response' do
        response = client.task_by_guid('some-guid')

        expected_request = Bbs::Models::TaskByGuidRequest.new(task_guid: 'some-guid')

        expect(response.error).to be_nil
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/tasks/get_by_task_guid.r2').with(
                 body: expected_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
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
          stub_request(:post, 'https://bbs.example.com:4443/v1/tasks/get_by_task_guid.r2').to_raise(StandardError.new('error message'))
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
      let(:response_body) { Bbs::Models::TaskLifecycleResponse.new(error: nil).encode.to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/tasks/cancel').to_return(status: response_status, body: response_body)
      end

      it 'returns a task lifecycle response' do
        expected_cancel_request = Bbs::Models::TaskGuidRequest.new(task_guid: 'some-guid')

        response = client.cancel_task('some-guid')

        expect(response.error).to be_nil
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/tasks/cancel').with(
                 body: expected_cancel_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
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
          stub_request(:post, 'https://bbs.example.com:4443/v1/tasks/cancel').to_raise(StandardError.new('error message'))
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
      let(:response_body) { Bbs::Models::DesiredLRPLifecycleResponse.new(error: nil).encode.to_s }
      let(:response_status) { 200 }
      let(:lrp) { ::Diego::Bbs::Models::DesiredLRP.new }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/desired_lrp/desire.r2').to_return(status: response_status, body: response_body)
      end

      it 'returns a Desired LRP Lifecycle Response' do
        expected_desire_lrp_request = Bbs::Models::DesireLRPRequest.new(desired_lrp: lrp)

        response = client.desire_lrp(lrp)
        expect(response).to be_a(Bbs::Models::DesiredLRPLifecycleResponse)
        expect(response.error).to be_nil
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/desired_lrp/desire.r2').with(
                 body: expected_desire_lrp_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
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
          stub_request(:post, 'https://bbs.example.com:4443/v1/desired_lrp/desire.r2').to_raise(StandardError.new('error message'))
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
      let(:response_body) { Bbs::Models::DesiredLRPResponse.new(error: nil, desired_lrp: lrp).encode.to_s }
      let(:response_status) { 200 }

      let(:process_guid) { 'process-guid' }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/desired_lrps/get_by_process_guid.r2').to_return(status: response_status, body: response_body)
      end

      it 'returns a Desired LRP Response' do
        expected_request = Bbs::Models::DesiredLRPByProcessGuidRequest.new(process_guid: process_guid)

        response = client.desired_lrp_by_process_guid(process_guid)
        expect(response).to be_a(Bbs::Models::DesiredLRPResponse)
        expect(response.error).to be_nil
        expect(response.desired_lrp).to eq(lrp)
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/desired_lrps/get_by_process_guid.r2').with(
                 body: expected_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
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
          stub_request(:post, 'https://bbs.example.com:4443/v1/desired_lrps/get_by_process_guid.r2').to_raise(StandardError.new('error message'))
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
      let(:response_body) { Bbs::Models::DesiredLRPLifecycleResponse.new(error: nil).encode.to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/desired_lrp/remove').to_return(status: response_status, body: response_body)
      end

      it 'returns a Desired LRP Lifecycle Response' do
        expected_request = Bbs::Models::RemoveDesiredLRPRequest.new(process_guid: process_guid)

        response = client.remove_desired_lrp(process_guid)
        expect(response).to be_a(Bbs::Models::DesiredLRPLifecycleResponse)
        expect(response.error).to be_nil
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/desired_lrp/remove').with(
                 body: expected_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
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
          stub_request(:post, 'https://bbs.example.com:4443/v1/desired_lrp/remove').to_raise(StandardError.new('error message'))
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
      let(:response_body) { Bbs::Models::ActualLRPLifecycleResponse.new(error: nil).encode.to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/actual_lrps/retire').to_return(status: response_status, body: response_body)
      end

      it 'returns an Actual LRP Lifecycle Response' do
        expected_request = Bbs::Models::RetireActualLRPRequest.new(actual_lrp_key: actual_lrp_key)

        response = client.retire_actual_lrp(actual_lrp_key)
        expect(response).to be_a(Bbs::Models::ActualLRPLifecycleResponse)
        expect(response.error).to be_nil
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/actual_lrps/retire').with(
                 body: expected_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
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
          stub_request(:post, 'https://bbs.example.com:4443/v1/actual_lrps/retire').to_raise(StandardError.new('error message'))
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

    describe '#with_request_error_handling' do
      it 'retries' do
        tries = 0

        client.with_request_error_handling do
          tries += 1
          raise 'error' if tries < 2
        end

        expect(tries).to be > 1
      end

      it 'raises an error after all retries fail' do
        expect {
          client.with_request_error_handling { raise 'error' }
        }.to raise_error(RequestError)
      end
    end

    describe '#update_desired_lrp' do
      let(:process_guid) { 'process-guid' }
      let(:lrp_update) { ::Diego::Bbs::Models::DesiredLRPUpdate.new(instances: 3) }

      let(:response_body) { Bbs::Models::DesiredLRPLifecycleResponse.new(error: nil).encode.to_s }
      let(:response_status) { 200 }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/desired_lrp/update').to_return(status: response_status, body: response_body)
      end

      it 'returns a Desired LRP Lifecycle Response' do
        expected_request = Bbs::Models::UpdateDesiredLRPRequest.new(process_guid: process_guid, update: lrp_update)

        response = client.update_desired_lrp(process_guid, lrp_update)
        expect(response).to be_a(Bbs::Models::DesiredLRPLifecycleResponse)
        expect(response.error).to be_nil
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/desired_lrp/update').with(
                 body: expected_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
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
          stub_request(:post, 'https://bbs.example.com:4443/v1/desired_lrp/update').to_raise(StandardError.new('error message'))
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

    describe '#actual_lrp_groups_by_process_guid' do
      let(:process_guid) { 'process-guid' }

      let(:response_body) { Bbs::Models::ActualLRPGroupsResponse.new(error: nil, actual_lrp_groups: actual_lrp_groups).encode.to_s }
      let(:actual_lrp_groups) { [::Diego::Bbs::Models::ActualLRPGroup.new] }
      let(:response_status) { 200 }
      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/actual_lrp_groups/list_by_process_guid').to_return(status: response_status, body: response_body)
      end

      it 'returns a LRP instances response' do
        expected_request = Bbs::Models::ActualLRPGroupsByProcessGuidRequest.new(process_guid: process_guid)

        response = client.actual_lrp_groups_by_process_guid(process_guid)
        expect(response).to be_a(Bbs::Models::ActualLRPGroupsResponse)
        expect(response.error).to be_nil
        expect(response.actual_lrp_groups).to eq(actual_lrp_groups)
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/actual_lrp_groups/list_by_process_guid').with(
                 body: expected_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
      end
    end

    describe '#desired_lrps_scheduling_infos' do
      let(:scheduling_infos) { [::Diego::Bbs::Models::DesiredLRPSchedulingInfo.new] }
      let(:response_body) { Bbs::Models::DesiredLRPSchedulingInfosResponse.new(error: nil, desired_lrp_scheduling_infos: scheduling_infos).encode.to_s }
      let(:response_status) { 200 }
      let(:domain) { 'domain' }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/desired_lrp_scheduling_infos/list').to_return(status: response_status, body: response_body)
      end

      it 'returns a Desired LRP Scheduling Infos Response' do
        expected_request = Bbs::Models::DesiredLRPsRequest.new(domain: domain)

        response = client.desired_lrp_scheduling_infos(domain)
        expect(response).to be_a(Bbs::Models::DesiredLRPSchedulingInfosResponse)
        expect(response.error).to be_nil
        expect(response.desired_lrp_scheduling_infos).to eq(scheduling_infos)
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/desired_lrp_scheduling_infos/list').with(
                 body: expected_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
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
          stub_request(:post, 'https://bbs.example.com:4443/v1/desired_lrp_scheduling_infos/list').to_raise(StandardError.new('error message'))
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

    describe '#with_request_error_handling' do
      it 'retries' do
        tries = 0

        client.with_request_error_handling do
          tries += 1
          raise 'error' if tries < 2
        end

        expect(tries).to be > 1
      end

      it 'raises an error after all retries fail' do
        expect {
          client.with_request_error_handling { raise 'error' }
        }.to raise_error(RequestError)
      end
    end
  end
end
