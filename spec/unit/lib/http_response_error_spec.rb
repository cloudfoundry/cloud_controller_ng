require 'spec_helper'

RSpec.describe HttpResponseError do
  let(:endpoint) { 'http://www.example.com/' }

  describe '#initialize' do
    context 'when the method is a symbol' do
      it 'converts method to an uppercase string' do
        exception = HttpResponseError.new('message', endpoint, :put, double(code: 500, reason: '', body: ''))
        expect(exception.method).to eq('PUT')
      end
    end

    context 'when the status code is a string' do
      it 'converts the status to a number' do
        exception = HttpResponseError.new('message', endpoint, 'PUT', double(code: '500', reason: '', body: ''))
        expect(exception.status).to eq(500)
      end
    end
  end

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
