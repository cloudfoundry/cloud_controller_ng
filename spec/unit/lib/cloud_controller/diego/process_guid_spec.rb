require 'spec_helper'
require 'cloud_controller/diego/process_guid'

module VCAP::CloudController::Diego
  describe ProcessGuid do
    let(:app) do
      VCAP::CloudController::AppFactory.make
    end

    describe 'process_guid' do
      it 'returns the appropriate composed guid' do
        expect(ProcessGuid.from(app.guid, app.version)).to eq("#{app.guid}-#{app.version}")
      end
    end

    describe 'from_app' do
      it 'returns the appropriate versioned guid for the app' do
        expect(ProcessGuid.from_app(app)).to eq("#{app.guid}-#{app.version}")
      end
    end

    describe 'app_guid' do
      it 'it returns the app guid from the versioned guid' do
        expect(ProcessGuid.app_guid(ProcessGuid.from_app(app))).to eq(app.guid)
      end
    end

    describe 'app_version' do
      it 'it returns the app version from the versioned guid' do
        expect(ProcessGuid.app_version(ProcessGuid.from_app(app))).to eq(app.version)
      end
    end
  end
end
