require 'spec_helper'
require 'cloud_controller/diego/process_guid'

module VCAP::CloudController::Diego
  RSpec.describe ProcessGuid do
    let(:process) do
      VCAP::CloudController::AppFactory.make
    end

    describe 'process_guid' do
      it 'returns the appropriate composed guid' do
        expect(ProcessGuid.from(process.guid, process.version)).to eq("#{process.guid}-#{process.version}")
      end
    end

    describe 'from_app' do
      it 'returns the appropriate versioned guid for the app' do
        expect(ProcessGuid.from_process(process)).to eq("#{process.guid}-#{process.version}")
      end
    end

    describe 'app_guid' do
      it 'it returns the app guid from the versioned guid' do
        expect(ProcessGuid.app_guid(ProcessGuid.from_process(process))).to eq(process.guid)
      end
    end

    describe 'app_version' do
      it 'it returns the app version from the versioned guid' do
        expect(ProcessGuid.app_version(ProcessGuid.from_process(process))).to eq(process.version)
      end
    end
  end
end
