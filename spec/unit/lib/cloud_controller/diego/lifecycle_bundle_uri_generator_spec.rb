require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe LifecycleBundleUriGenerator do
      before do
        TestConfig.override({ diego: { file_server_url: 'https://file-server.example.com:1234' } })
      end

      it 'creates a file server url for a bundle path' do
        expect(described_class.uri('path/bundle.tgz')).to eq('https://file-server.example.com:1234/v1/static/path/bundle.tgz')
      end

      it 'returns an error when passed nil' do
        expect { described_class.uri(nil) }.to raise_error(CloudController::Errors::ApiError, /no compiler defined for requested stack/)
      end

      it 'returns back a full url' do
        expect(described_class.uri('http://bundle.example.com')).to eq('http://bundle.example.com')
      end

      it 'raises an error for a non http or https url' do
        expect { described_class.uri('ftp://bundle.example.com') }.to raise_error(CloudController::Errors::ApiError, /invalid compiler URI/)
      end
    end
  end
end
