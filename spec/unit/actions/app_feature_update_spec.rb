require 'spec_helper'
require 'actions/app_feature_update'
require 'messages/app_feature_update_message'

module VCAP::CloudController
  RSpec.describe AppFeatureUpdate do
    subject(:app_feature_update) { AppFeatureUpdate }
    let(:app) { AppModel.make(enable_ssh: false, revisions_enabled: false, service_binding_k8s_enabled: false, file_based_vcap_services_enabled: false) }

    describe '.update' do
      let(:message) { AppFeatureUpdateMessage.new(enabled: true) }

      context 'when the feature name is ssh' do
        it 'updates the enable_ssh column on the app' do
          expect do
            AppFeatureUpdate.update('ssh', app, message)
          end.to change { app.reload.enable_ssh }.to(true)
        end
      end

      context 'when the feature name is revisions' do
        it 'updates the revisions_enabled column on the app' do
          expect do
            AppFeatureUpdate.update('revisions', app, message)
          end.to change { app.reload.revisions_enabled }.to(true)
        end
      end

      context 'when the feature name is service-binding-k8s' do
        it 'updates the service_binding_k8s_enabled column on the app' do
          expect do
            AppFeatureUpdate.update('service-binding-k8s', app, message)
          end.to change { app.reload.service_binding_k8s_enabled }.to(true)
        end
      end

      context 'when the feature name is file-based-vcap-services' do
        it 'updates the file_based_vcap_services_enabled column on the app' do
          expect do
            AppFeatureUpdate.update('file-based-vcap-services', app, message)
          end.to change { app.reload.file_based_vcap_services_enabled }.to(true)
        end
      end
    end

    describe '.bulk_update' do
      let(:features) do
        {
          ssh: false,
          revisions: false,
          'service-binding-k8s': false,
          'file-based-vcap-services': false
        }
      end
      let(:message) { ManifestFeaturesUpdateMessage.new(features:) }

      context 'when the ssh feature is specified' do
        before do
          features[:ssh] = true
        end

        it 'updates the enable_ssh column on the app' do
          expect do
            AppFeatureUpdate.bulk_update(app, message)
          end.to change { app.reload.enable_ssh }.to(true)
        end
      end

      context 'when the revisions feature is specified' do
        before do
          features[:revisions] = true
        end

        it 'updates the revisions_enabled column on the app' do
          expect do
            AppFeatureUpdate.bulk_update(app, message)
          end.to change { app.reload.revisions_enabled }.to(true)
        end
      end

      context 'when the service-binding-k8s feature is specified' do
        before do
          features[:'service-binding-k8s'] = true
        end

        it 'updates the service_binding_k8s_enabled column on the app' do
          expect do
            AppFeatureUpdate.bulk_update(app, message)
          end.to change { app.reload.service_binding_k8s_enabled }.to(true)
        end
      end

      context 'when the file-based-vcap-services feature is specified' do
        before do
          features[:'file-based-vcap-services'] = true
        end

        it 'updates the file_based_vcap_services_enabled column on the app' do
          expect do
            AppFeatureUpdate.bulk_update(app, message)
          end.to change { app.reload.file_based_vcap_services_enabled }.to(true)
        end
      end

      context 'when multiple features are specified' do
        before do
          features[:ssh] = true
          features[:'service-binding-k8s'] = true
        end

        it 'updates the corresponding columns in a single database call' do
          expect(app.enable_ssh).to be(false)
          expect(app.service_binding_k8s_enabled).to be(false)

          expect do
            AppFeatureUpdate.bulk_update(app, message)
          end.to have_queried_db_times(/update .apps./i, 1)

          app.reload
          expect(app.enable_ssh).to be(true)
          expect(app.service_binding_k8s_enabled).to be(true)
        end
      end

      context 'when conflicting features are specified' do
        before do
          features[:'service-binding-k8s'] = true
          features[:'file-based-vcap-services'] = true
        end

        it 'raises an error' do
          expect do
            AppFeatureUpdate.bulk_update(app, message)
          end.to raise_error(AppFeatureUpdate::InvalidCombination, /'file-based-vcap-services' and 'service-binding-k8s' features cannot be enabled at the same time/)
        end
      end
    end
  end
end
