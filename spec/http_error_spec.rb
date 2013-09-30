require 'spec_helper'

describe HttpError do
  let(:endpoint) { 'http://www.example.com/' }
  let(:response_body) do
    { 'foo' => 'bar' }.to_json
  end
  let(:response) { double(code: 500, reason: 'Internal Server Error', body: response_body) }

  it 'parses the response as JSON' do
    exception = described_class.new('some msg', endpoint, 'GET', response)

    expect(exception.error).to eq({
      'foo' => 'bar'
    })
  end

  context 'when the response body is plain text' do
    let(:response_body) { 'not JSON' }

    it 'parses the response as plain text' do
      exception = described_class.new('some msg', endpoint, 'GET', response)

      expect(exception.error).to eq('not JSON')
    end
  end


end

describe NonResponsiveHttpError do
  let(:endpoint) { 'http://www.example.com/' }

  it 'creates a VCAP exception' do
    exception = described_class.new('some msg', SocketError.new, endpoint, 'PUT', 314159)
  end
end
