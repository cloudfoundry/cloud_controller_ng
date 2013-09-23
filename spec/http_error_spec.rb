require 'spec_helper'

describe HttpError do
  let(:endpoint) { 'http://www.example.com/' }
  let(:response_body) do
    { 'foo' => 'bar' }.to_json
  end
  let(:response) { double(code: 500, reason: 'Internal Server Error', body: response_body) }

  it 'generates the correct hash' do
    exception = described_class.new('some msg', endpoint, response)

    expect(exception.to_h).to include({
      'status' => 500,
      'endpoint' => endpoint,
    })
  end

end