require 'spec_helper'

RSpec.describe HttpRequestError do
  let(:endpoint) { 'http://www.example.com/' }
  let(:nested_exception) { SocketError.new }

  describe '#initialize' do
    context 'when the method is a symbol' do
      it 'converts method to an uppercase string' do
        exception = HttpRequestError.new('message', endpoint, :put, nested_exception)
        expect(exception.method).to eq('PUT')
      end
    end
  end

  it 'produces the correct hash' do
    exception = HttpRequestError.new('message', endpoint, 'PUT', nested_exception)
    expect(exception.to_h).to include({
      'description' => 'message',
      'http' => {
        'uri' => endpoint,
        'method' => 'PUT'
      }
    })
  end
end
