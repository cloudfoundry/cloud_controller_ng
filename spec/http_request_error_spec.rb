require 'spec_helper'

describe HttpRequestError do
  let(:endpoint) { 'http://www.example.com/' }
  let(:nested_exception) { SocketError.new }

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


