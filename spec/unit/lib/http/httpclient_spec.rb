require 'http/httpclient'

RSpec.describe HTTPClient do
  describe 'version' do
    it 'should not be updated' do
      expect(HTTPClient::VERSION).to eq('2.8.3'), 'revisit monkey patch in lib/http/httpclient.rb'
    end
  end

  describe 're-raising errors' do
    let(:client) { double(socket_connect_timeout: nil) }

    it 'adds host and port to the error message' do
      allow(TCPSocket).to receive(:new).and_raise(Errno::ECONNREFUSED)

      session = HTTPClient::Session.new(client, nil, nil, nil)
      expect { session.create_socket('host', 123) }.to raise_error(SystemCallError, /(host:123)/)
    end
  end
end
