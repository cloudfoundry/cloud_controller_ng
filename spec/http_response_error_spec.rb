require 'spec_helper'

describe HttpResponseError do
  let(:endpoint) { 'http://www.example.com/' }

  context 'when the server returns a json structure' do
    let(:response_hash) do
      { 'foo' => 'bar' }
    end
    let(:response) { double(code: 500, reason: 'Internal Server Error', body: response_hash.to_json) }

    it 'produces the correct hash' do
      exception = HttpResponseError.new('message', endpoint, 'PUT', response)
      expect(exception.to_h).to include({
        'description' => 'message',
        'http' => {
          'uri' => endpoint,
          'method' => 'PUT',
          'status' => 500,
        },
        'source' => response_hash,
      })
    end
  end

  context 'when the server returns a bunch of text' do
    let(:response_string) { 'foo' }
    let(:response) { double(code: 500, reason: 'Internal Server Error', body: response_string) }

    it 'produces the correct hash' do
      exception = HttpResponseError.new('message', endpoint, 'PUT', response)
      expect(exception.to_h).to include({
        'description' => 'message',
        'http' => {
          'uri' => endpoint,
          'method' => 'PUT',
          'status' => 500,
        },
        'source' => response_string,
      })
    end
  end

end
