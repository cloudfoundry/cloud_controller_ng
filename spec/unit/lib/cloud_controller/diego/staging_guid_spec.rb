require 'spec_helper'
require 'cloud_controller/diego/staging_guid'

module VCAP::CloudController::Diego
  RSpec.describe StagingGuid do
    let(:app) do
      VCAP::CloudController::AppFactory.make(staging_task_id: Sham.guid)
    end

    describe 'staging_guid' do
      it 'returns the appropriate composed guid' do
        expect(StagingGuid.from(app.guid, app.staging_task_id)).to eq("#{app.guid}-#{app.staging_task_id}")
      end
    end

    describe 'from_app' do
      it 'returns the appropriate versioned guid for the app' do
        expect(StagingGuid.from_process(app)).to eq("#{app.guid}-#{app.staging_task_id}")
      end
    end

    describe 'app_guid' do
      it 'it returns the app guid from the versioned guid' do
        expect(StagingGuid.process_guid(StagingGuid.from_process(app))).to eq(app.guid)
      end
    end

    describe 'staging_task_id' do
      it 'it returns the app version from the versioned guid' do
        expect(StagingGuid.staging_task_id(StagingGuid.from_process(app))).to eq(app.staging_task_id)
      end
    end

    context 'when the staging_task_id is not set on the app' do
      let(:app) do
        VCAP::CloudController::AppFactory.make
      end

      it 'returns nil' do
        expect(StagingGuid.from_process(app)).to be_nil
      end
    end
  end
end
