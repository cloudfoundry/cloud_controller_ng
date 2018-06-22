require 'spec_helper'
require 'cloud_controller/diego/process_guid'

module VCAP::CloudController::Diego
  RSpec.describe ProcessGuid do
    let(:process) do
      VCAP::CloudController::ProcessModelFactory.make
    end

    describe 'process_guid' do
      it 'returns the appropriate composed Diego process guid' do
        expect(ProcessGuid.from(process.guid, process.version)).to eq("#{process.guid}-#{process.version}")
      end
    end

    describe 'from_process' do
      it 'returns the appropriate versioned guid for the CC ProcessModel' do
        expect(ProcessGuid.from_process(process)).to eq("#{process.guid}-#{process.version}")
      end
    end

    describe 'cc_process_guid' do
      it 'it returns the CC ProcessModel guid from the versioned Diego process guid' do
        expect(ProcessGuid.cc_process_guid(ProcessGuid.from_process(process))).to eq(process.guid)
      end
    end

    describe 'cc_process_version' do
      it 'it returns the CC ProcessModel version from the versioned Diego process guid' do
        expect(ProcessGuid.cc_process_version(ProcessGuid.from_process(process))).to eq(process.version)
      end
    end
  end
end
