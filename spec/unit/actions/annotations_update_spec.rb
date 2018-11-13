require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AnnotationsUpdate do
    describe 'apps annotations' do
      subject(:result) { AnnotationsUpdate.update(app, annotations, AppAnnotationModel) }

      let(:app) { AppModel.make }
      let(:annotations) do
        {
          release: 'stable',
        }
      end

      it 'updates the annotations' do
        subject
        expect(AppAnnotationModel.find(resource_guid: app.guid, key: 'release').value).to eq 'stable'
      end

      context 'no annotation updates' do
        let(:annotations) { nil }

        it 'does not change any annotations' do
          expect do
            subject
          end.not_to change { AppAnnotationModel.count }
        end
      end

      context 'when existing annotations are being modified' do
        let(:annotations) do
          {
            release: 'stable',
          }
        end

        let!(:old_annotation) do
          AppAnnotationModel.create(resource_guid: app.guid, key: 'release', value: 'unstable')
        end

        it 'updates the old annotation' do
          subject
          expect(old_annotation.reload.value).to eq 'stable'
        end
      end
    end
  end
end
