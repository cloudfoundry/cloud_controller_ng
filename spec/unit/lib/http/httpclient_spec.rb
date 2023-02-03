require 'httpclient'

RSpec.describe HTTPClient do
  describe 'version' do
    it 'should not be updated' do
      expect(HTTPClient::VERSION).to eq('2.8.3'), 'revisit monkey patch in lib/http/httpclient.rb'
    end
  end
end
