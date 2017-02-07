require 'spec_helper'
require 'traffic_controller/client'
require 'openssl'

module TrafficController
  RSpec.describe Client do
    let(:doppler_url) { 'https://doppler.example.com:4443' }

    subject(:client) { Client.new(url: doppler_url) }
    let(:expected_request_options) { { 'headers' => { 'Authorization' => 'bearer oauth-token' } } }

    def build_response_body(boundary, encoded_envelopes)
      body = []
      encoded_envelopes.each do |env|
        body << "--#{boundary}"
        body << ''
        body << env
      end
      body << "--#{boundary}--"

      body.join("\r\n")
    end

    describe '#container_metrics' do
      let(:auth_token) { 'bearer oauth-token' }
      let(:response_boundary) { SecureRandom.uuid }
      let(:response_body) do
        build_response_body(response_boundary, [
          Models::Envelope.new(origin: 'a', eventType: Models::Envelope::EventType::ContainerMetric).encode.to_s,
          Models::Envelope.new(origin: 'b', eventType: Models::Envelope::EventType::ContainerMetric).encode.to_s,
        ])
      end
      let(:response_status) { 200 }
      let(:response_headers) { { 'Content-Type' => "multipart/x-protobuf; boundary=#{response_boundary}" } }

      before do
        stub_request(:get, 'https://doppler.example.com:4443/apps/example-app-guid/containermetrics').
          with(expected_request_options).
          to_return(status: response_status, body: response_body, headers: response_headers)
      end

      it 'returns an array of Envelopes' do
        expect(client.container_metrics(auth_token: auth_token, app_guid: 'example-app-guid')).to match_array([
          Models::Envelope.new(origin: 'a', eventType: Models::Envelope::EventType::ContainerMetric),
          Models::Envelope.new(origin: 'b', eventType: Models::Envelope::EventType::ContainerMetric),
        ])
        expect(a_request(:get, 'https://doppler.example.com:4443/apps/example-app-guid/containermetrics')).to have_been_made
      end

      context 'when it does not return successfully' do
        let(:response_status) { 404 }
        let(:response_body) { 'not found' }

        it 'raises' do
          expect { client.container_metrics(auth_token: auth_token, app_guid: 'example-app-guid') }.to raise_error(ResponseError, /status: 404, body: not found/)
        end
      end

      context 'when it fails to make the request' do
        before do
          stub_request(:get, 'https://doppler.example.com:4443/apps/example-app-guid/containermetrics').to_raise(StandardError.new('error message'))
        end

        it 'raises' do
          expect { client.container_metrics(auth_token: auth_token, app_guid: 'example-app-guid') }.to raise_error(RequestError, /error message/)
        end
      end

      context 'when the response is not a valid multipart body' do
        let(:response_body) { '' }

        it 'returns an empty array' do
          expect(client.container_metrics(auth_token: auth_token, app_guid: 'example-app-guid')).to be_empty
        end
      end

      context 'when the response does not contain the boundary in the "Content-Type" header' do
        let(:response_headers) { { 'Content-Type' => 'potato' } }

        it 'raises' do
          expect {
            client.container_metrics(auth_token: auth_token, app_guid: 'example-app-guid')
          }.to raise_error(ResponseError, 'failed to find multipart boundary in Content-Type header')
        end
      end

      context 'when a part cannot be decoded by ProtoBuf' do
        let(:response_body) do
          build_response_body(response_boundary, [
            Models::Envelope.new(origin: 'a', eventType: Models::Envelope::EventType::ContainerMetric).encode.to_s,
            'potato',
          ])
        end

        it 'raises' do
          expect { client.container_metrics(auth_token: auth_token, app_guid: 'example-app-guid') }.to raise_error(DecodeError)
        end
      end
    end
  end

  RSpec.describe Client::MultipartParser do
    subject(:parser) { Client::MultipartParser.new(body: body, boundary: boundary) }
    describe '#next_part' do
      let(:body) do
        [
          "--#{boundary}",
          "\r\n",
          "\r\n",
          first_part,
          "\r\n",
          "--#{boundary}",
          "\r\n",
          "\r\n",
          second_part,
          "\r\n",
          "--#{boundary}--",
        ].join('')
      end
      let(:boundary) { 'boundary-guid' }
      let(:first_part) { 'part one data' }
      let(:second_part) { 'part two data' }

      it 'can return the first part' do
        expect(parser.next_part).to eq('part one data')
      end

      it 'can read more than one part' do
        expect(parser.next_part).to eq('part one data')
        expect(parser.next_part).to eq('part two data')
      end

      context 'when there are no parts left' do
        it 'returns nil' do
          expect(parser.next_part).to eq('part one data')
          expect(parser.next_part).to eq('part two data')
          expect(parser.next_part).to be_nil
        end
      end

      context 'when there body contains no parts' do
        let(:body) { "\r\n--#{boundary}--\r\n" }
        it 'returns nil' do
          expect(parser.next_part).to be_nil
        end
      end

      context 'when the body is empty' do
        let(:body) { '' }

        it 'returns nil' do
          expect(parser.next_part).to be_nil
        end
      end

      context 'when the body is not a valid multipart response' do
        let(:body) { 'potato' }

        it 'returns nil' do
          expect(parser.next_part).to be_nil
        end
      end
    end
  end
end
