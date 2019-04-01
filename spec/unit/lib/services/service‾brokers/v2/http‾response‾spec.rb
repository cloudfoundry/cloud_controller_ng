require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe HttpResponse do
    describe '#initialize' do
      let(:response_attrs) { { code: 200, body: {} } }

      context 'when headers are passed as attrs' do
        it 'should allow case-insensitive access to headers' do
          res = HttpResponse.new(response_attrs.merge({ headers: { 'HeAdEr-KeY' => 'value' } }))

          expect(res['Header-Key']).to eql('value')
        end
      end

      context 'when no headers are passed' do
        it 'should not raise' do
          expect { HttpResponse.new(response_attrs) }.not_to raise_error
        end
      end

      context 'when no message is given' do
        it 'should derive it from the status code' do
          res = HttpResponse.new(response_attrs)

          expect(res.message).to eql('OK')
        end
      end
    end

    describe '#from_http_client_response' do
      let(:client_response) { double(:response, code: status_code, reason: 'custom message', body: {}.to_json, headers: {}) }

      context 'maps status codes to status code messages' do
        status_messages = [
          # RFC 2616
          [100, 'Continue'],
          [101, 'Switching Protocols'],
          [200, 'OK'],
          [201, 'Created'],
          [202, 'Accepted'],
          [203, 'Non-Authoritative Information'],
          [204, 'No Content'],
          [205, 'Reset Content'],
          [206, 'Partial Content'],
          [300, 'Multiple Choices'],
          [301, 'Moved Permanently'],
          [302, 'Found'],
          [303, 'See Other'],
          [304, 'Not Modified'],
          [305, 'Use Proxy'],
          [307, 'Temporary Redirect'],
          [400, 'Bad Request'],
          [401, 'Unauthorized'],
          [402, 'Payment Required'],
          [403, 'Forbidden'],
          [404, 'Not Found'],
          [405, 'Method Not Allowed'],
          [406, 'Not Acceptable'],
          [407, 'Proxy Authentication Required'],
          [408, 'Request Timeout'],
          [410, 'Gone'],
          [411, 'Length Required'],
          [412, 'Precondition Failed'],
          [413, 'Request Entity Too Large'],
          [414, 'Request-URI Too Long'],
          [415, 'Unsupported Media Type'],
          [416, 'Requested Range Not Satisfiable'],
          [417, 'Expectation Failed'],
          [418, "I'm a Teapot"],
          [500, 'Internal Server Error'],
          [501, 'Not Implemented'],
          [502, 'Bad Gateway'],
          [503, 'Service Unavailable'],
          [504, 'Gateway Timeout'],
          [505, 'HTTP Version Not Supported'],
          # RFC 6585 (Experimental status codes)
          [428, 'Precondition Required'],
          [429, 'Too Many Requests'],
          [431, 'Request Header Fields Too Large'],
          [511, 'Network Authentication Required'],
          # WebDAV
          [422, 'Unprocessable Entity'],
          [423, 'Locked'],
          [424, 'Failed Dependency'],
          [507, 'Insufficient Storage'],
          [508, 'Loop Detected']
        ]

        status_messages.each do |mapping|
          code = mapping.first
          message = mapping.last

          context "when the broker returns a #{code}" do
            let(:status_code) { code }

            it "returns an http response with a message of `#{message}`" do
              res = HttpResponse.from_http_client_response(client_response)

              expect(res.message).to eq(message)
            end
          end
        end

        context 'when the broker returns an unknown status code' do
          let(:status_code) { 600 }

          it 'returns the custom status code message' do
            res = HttpResponse.from_http_client_response(client_response)

            expect(res.message).to eq('custom message')
          end
        end
      end
    end
  end
end
