require 'spec_helper'
require 'actions/app_feature_update'
require 'messages/app_feature_update_message'

module VCAP::CloudController
  RSpec.describe AppFeatureUpdate do
    subject(:app_feature_update) { AppFeatureUpdate }
    let(:app) { AppModel.make(enable_ssh: false, revisions_enabled: false) }
    let(:message) { AppFeatureUpdateMessage.new(enabled: true) }

    describe '.update' do
      context 'when the feature name is ssh' do
        it 'updates the enable_ssh column on the app' do
          expect {
            AppFeatureUpdate.update('ssh', app, message)
          }.to change { app.reload.enable_ssh }.to(true)
        end
      end

      context 'when the feature name is revisions' do
        it 'updates the revisions_enabled column on the app' do
          expect {
            AppFeatureUpdate.update('revisions', app, message)
          }.to change { app.reload.revisions_enabled }.to(true)
        end
      end
    end
  end
end
