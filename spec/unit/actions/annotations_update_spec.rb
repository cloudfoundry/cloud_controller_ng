require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AnnotationsUpdate do
    describe 'apps annotations' do
      subject(:result) do
        app.db.transaction do
          AnnotationsUpdate.update(app, annotations, AppAnnotationModel)
        end
      end

      let(:app) { AppModel.make }
      let(:annotations) do
        {
          'clodefloundry.org/release': 'stable',
        }
      end

      it 'updates the annotations' do
        AnnotationsUpdate.update(app, annotations, AppAnnotationModel)
        expect(AppAnnotationModel.find(resource_guid: app.guid, key_prefix: 'clodefloundry.org', key_name: 'release').value).to eq 'stable'
      end

      context 'when lazily migrating old annotations' do
        let!(:annotation_model) do
          AppAnnotationModel.create(resource_guid: app.guid, key_name: 'clodefloundry.org/release', value: 'stable2')
        end
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
            please: nil,
            'pre.fix/release': nil
          }
        end

        let!(:old_annotation) do
          AppAnnotationModel.create(resource_guid: app.guid, key_name: 'release', value: 'unstable')
        end

        let!(:annotation_to_be_deleted) do
          AppAnnotationModel.create(resource_guid: app.guid, key_name: 'please', value: 'delete me')
        end

        let!(:prefixed_annotation_to_be_deleted) do
          AppAnnotationModel.create(resource_guid: app.guid, key_prefix: 'pre.fix', key_name: 'release', value: 'delete me')
        end

        it 'updates the old annotation' do
          subject
          expect(old_annotation.reload.value).to eq 'stable'
          expect(AppAnnotationModel.find(resource_guid: app.guid, key_name: 'please')).to be_nil
          expect(AppAnnotationModel.find(resource_guid: app.guid, key_prefix: 'pre.fix', key_name: 'release')).to be_nil
          expect(AppAnnotationModel.count).to eq 1
        end

        it 'preserves label keys and sets values to nil when destroy_nil is false' do
          app.db.transaction do
            AnnotationsUpdate.update(app, annotations, AppAnnotationModel, destroy_nil: false)
          end

          expect(annotation_to_be_deleted.reload.value).to eq nil
          expect(prefixed_annotation_to_be_deleted.reload.value).to eq nil
          expect(old_annotation.reload.value).to eq 'stable'
        end
      end

      context 'too many annotations' do
        context 'annotations added exceeds max annotations' do
          let(:annotations) do
            {
              release: 'stable',
              asdf: 'mashed',
              bbq: 'hello',
              def: 'fdsa'
            }
          end

          it 'does not make any changes' do
            TestConfig.override(max_annotations_per_resource: 2)

            expect do
              expect do
                subject
              end.to raise_error(CloudController::Errors::ApiError, /Failed to add 4 annotations because it would exceed maximum of 2/)
            end.not_to change { AppAnnotationModel.count }
          end
        end

        context 'app already has max annotations' do
          context 'annotations added exceeds max annotations' do
            let!(:app_with_annotations) do
              AppAnnotationModel.create(resource_guid: app.guid, key_name: 'release1', value: 'veryunstable')
              AppAnnotationModel.create(resource_guid: app.guid, key_name: 'release2', value: 'stillunstable')
            end

            let(:annotations) do
              {
                release: 'stable',
              }
            end

            it 'does not make any changes' do
              TestConfig.override(max_annotations_per_resource: 2)

              expect do
                expect do
                  subject
                end.to raise_error(CloudController::Errors::ApiError, /Failed to add 1 annotations because it would exceed maximum of 2/)
              end.not_to change { AppAnnotationModel.count }
            end
          end
        end

        context 'annotations exceed max annotations' do
          let!(:app_with_annotations) do
            AppAnnotationModel.create(resource_guid: app.guid, key_name: 'release', value: 'unstable')
            AppAnnotationModel.create(resource_guid: app.guid, key_name: 'release1', value: 'veryunstable')
            AppAnnotationModel.create(resource_guid: app.guid, key_name: 'release2', value: 'stillunstable')
            AppAnnotationModel.create(resource_guid: app.guid, key_name: 'release3', value: 'help')
          end

          context 'deleting old annotation' do
            let(:annotations) do
              {
                release1: nil,
              }
            end

            it 'allows it' do
              TestConfig.override(max_annotations_per_resource: 2)
              subject

              expect(AppAnnotationModel.find(resource_guid: app.guid, key_name: 'release1')).to be_nil
            end
          end

          context 'editing old annotation' do
            let(:annotations) do
              {
                release: 'stable',
              }
            end

            it 'allows it' do
              TestConfig.override(max_annotations_per_resource: 2)
              subject

              expect(AppAnnotationModel.find(resource_guid: app.guid, key_name: 'release').value).to eq 'stable'
            end
          end
        end
      end
    end
  end
end
