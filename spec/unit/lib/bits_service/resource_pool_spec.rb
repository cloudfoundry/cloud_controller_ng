require 'spec_helper'
require 'securerandom'

module BitsService
  RSpec.describe ResourcePool do
    let(:endpoint) { 'http://bits-service.service.cf.internal/' }

    let(:guid) { SecureRandom.uuid }

    subject { ResourcePool.new(endpoint: endpoint) }

    describe 'forwards vcap-request-id' do
      let(:file_path) { Tempfile.new('buildpack').path }
      let(:file_name) { 'my-buildpack.zip' }

      it 'includes the header with a POST request' do
        expect(VCAP::Request).to receive(:current_id).at_least(:twice).and_return('0815')

        request = stub_request(:post, File.join(endpoint, 'app_stash/matches')).
                  with(headers: { 'X-Vcap-Request_Id' => '0815' }).
                  to_return(status: 200)

        subject.matches([].to_json)
        expect(request).to have_been_requested
      end
    end

    context 'Logging' do
      let!(:request) { stub_request(:post, File.join(endpoint, 'app_stash/matches')).to_return(status: 200) }
      let(:vcap_id) { 'VCAP-ID-1' }

      before do
        allow(VCAP::Request).to receive(:current_id).and_return(vcap_id)
      end

      it 'logs the request being made' do
        allow_any_instance_of(Steno::Logger).to receive(:info).with('Response', anything)

        expect_any_instance_of(Steno::Logger).to receive(:info).with('Request', {
          method: 'POST',
          path: '/app_stash/matches',
          address: 'bits-service.service.cf.internal',
          port: 80,
          vcap_id: vcap_id,
          request_id: anything
        })

        subject.matches([].to_json)
      end

      it 'logs the response being received' do
        allow_any_instance_of(Steno::Logger).to receive(:info).with('Request', anything)

        expect_any_instance_of(Steno::Logger).to receive(:info).with('Response', {
          code: '200',
          vcap_id: vcap_id,
          request_id: anything
        })

        subject.matches([].to_json)
      end

      it 'matches the request_id from the request in the reponse' do
        request_id = nil

        expect_any_instance_of(Steno::Logger).to receive(:info).with('Request', anything) do |_, _, data|
          request_id = data[:request_id]
        end

        expect_any_instance_of(Steno::Logger).to receive(:info).with('Response', anything) do |_, _, data|
          expect(data[:request_id]).to eq(request_id)
        end

        subject.matches([].to_json)
      end
    end

    context 'AppStash' do
      describe '#matches' do
        let(:resources) do
          [{ 'sha1' => 'abcde' }, { 'sha1' => '12345' }]
        end

        it 'makes the correct request to the bits endpoint' do
          request = stub_request(:post, File.join(endpoint, 'app_stash/matches')).
                    with(body: resources.to_json).
                    to_return(status: 200, body: [].to_json)

          subject.matches(resources.to_json)
          expect(request).to have_been_requested
        end

        it 'returns the request response' do
          stub_request(:post, File.join(endpoint, 'app_stash/matches')).
            with(body: resources.to_json).
            to_return(status: 200, body: [].to_json)

          response = subject.matches(resources.to_json)
          expect(response).to be_a(Net::HTTPOK)
        end

        it 'raises an error when the response is not 200' do
          stub_request(:post, File.join(endpoint, 'app_stash/matches')).
            to_return(status: 400, body: '{"description":"bits-failure"}')

          expect {
            subject.matches(resources.to_json)
          }.to raise_error(BitsService::Errors::Error, /bits-failure/)
        end
      end

      describe '#upload_entries' do
        let(:zip) { Tempfile.new('entry.zip') }

        it 'posts a zip file with new bits' do
          request = stub_request(:post, File.join(endpoint, 'app_stash/entries')).
                    with(body: /.*application".*/).
                    to_return(status: 201)

          subject.upload_entries(zip)
          expect(request).to have_been_requested
        end

        it 'returns the request response' do
          stub_request(:post, File.join(endpoint, 'app_stash/entries')).
            with(body: /.*application".*/).
            to_return(status: 201)

          response = subject.upload_entries(zip)
          expect(response).to be_a(Net::HTTPCreated)
        end

        it 'raises an error when the response is not 201' do
          stub_request(:post, File.join(endpoint, 'app_stash/entries')).
            to_return(status: 400, body: '{"description":"bits-failure"}')

          expect {
            subject.upload_entries(zip)
          }.to raise_error(BitsService::Errors::Error, /bits-failure/)
        end
      end

      describe '#bundles' do
        let(:order) {
          [{ 'fn' => 'app.rb', 'sha1' => '12345' }]
        }

        let(:content_bits) { 'tons of bits as ordered' }

        it 'makes the correct request to the bits service' do
          request = stub_request(:post, File.join(endpoint, 'app_stash/bundles')).
                    with(body: order.to_json).
                    to_return(status: 200, body: content_bits)

          subject.bundles(order.to_json)
          expect(request).to have_been_requested
        end

        it 'returns the request response' do
          stub_request(:post, File.join(endpoint, 'app_stash/bundles')).
            with(body: order.to_json).
            to_return(status: 200, body: content_bits)

          response = subject.bundles(order.to_json)
          expect(response).to be_a(Net::HTTPOK)
        end

        it 'raises an error when the response is not 200' do
          stub_request(:post, File.join(endpoint, 'app_stash/bundles')).
            to_return(status: 400, body: '{"description":"bits-failure"}')

          expect {
            subject.bundles(order.to_json)
          }.to raise_error(BitsService::Errors::Error, /bits-failure/)
        end
      end
    end
  end
end
