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
        let(:response_status) { 404 }
        let(:response_body) { 'not found' }

        it 'raises' do
          expect { client.ping }.to raise_error(ResponseError, /status: 404, body: not found/)
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

    describe '#desire_task' do
      let(:response_body) { Bbs::Models::TaskResponse.new(error: nil).encode.to_s }
      let(:response_status) { 200 }
      let(:task_definition) { Bbs::Models::TaskDefinition.new }

      before do
        stub_request(:post, 'https://bbs.example.com:4443/v1/tasks/desire.r2').to_return(status: response_status, body: response_body)
      end

      it 'returns a task response' do
        expected_task_request = Bbs::Models::DesireTaskRequest.new(task_definition: task_definition, task_guid: 'task_guid', domain: 'domain')

        response = client.desire_task(task_definition: task_definition, task_guid: 'task_guid', domain: 'domain')

        expect(response.error).to be_nil
        expect(a_request(:post, 'https://bbs.example.com:4443/v1/tasks/desire.r2').with(
                 body:    expected_task_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
      end

      context 'when it does not return successfully' do
        let(:response_status) { 404 }
        let(:response_body) { 'not found' }

        it 'raises' do
          expect { client.desire_task(task_definition: task_definition, task_guid: 'task_guid', domain: 'domain') }.to raise_error(ResponseError, /status: 404, body: not found/)
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
                 body:    expected_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
      end

      describe 'filtering' do
        it 'filters by domain' do
          response = client.tasks(domain: 'some-domain')

          expected_request = Bbs::Models::TasksRequest.new(domain: 'some-domain')

          expect(response.error).to be_nil
          expect(a_request(:post, 'https://bbs.example.com:4443/v1/tasks/list.r2').with(
                   body:    expected_request.encode.to_s,
                   headers: { 'Content-Type' => 'application/x-protobuf' }
          )).to have_been_made
        end

        it 'filters by cell_id' do
          response = client.tasks(cell_id: 'cell-id-thing')

          expected_request = Bbs::Models::TasksRequest.new(cell_id: 'cell-id-thing')

          expect(response.error).to be_nil
          expect(a_request(:post, 'https://bbs.example.com:4443/v1/tasks/list.r2').with(
                   body:    expected_request.encode.to_s,
                   headers: { 'Content-Type' => 'application/x-protobuf' }
          )).to have_been_made
        end
      end

      context 'when it does not return successfully' do
        let(:response_status) { 404 }
        let(:response_body) { 'not found' }

        it 'raises' do
          expect { client.tasks }.to raise_error(ResponseError, /status: 404, body: not found/)
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
                 body:    expected_request.encode.to_s,
                 headers: { 'Content-Type' => 'application/x-protobuf' }
        )).to have_been_made
      end

      context 'when it does not return successfully' do
        let(:response_status) { 404 }
        let(:response_body) { 'not found' }

        it 'raises' do
          expect { client.task_by_guid('some-guid') }.to raise_error(ResponseError, /status: 404, body: not found/)
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
