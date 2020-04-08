require 'spec_helper'
require 'actions/labels_update'

module VCAP::CloudController
  RSpec.describe LabelsUpdate do
    describe 'apps labels' do
      subject(:result) do
        app.db.transaction do
          LabelsUpdate.update(app, labels, AppLabelModel)
        end
      end

      let(:app) { AppModel.make }
      let(:labels) do
        {
            release: 'stable',
            'joyofcooking.com/potato': 'mashed'
        }
      end

      it 'updates the labels' do
        subject
        expect(AppLabelModel.find(resource_guid: app.guid, key_name: 'release').value).to eq 'stable'
        expect(AppLabelModel.find(resource_guid: app.guid, key_prefix: 'joyofcooking.com', key_name: 'potato').value).to eq 'mashed'
      end

      context 'too many labels' do
        context 'labels added exceeds max labels' do
          let(:labels) do
            {
              release: 'stable',
              asdf: 'mashed',
              bbq: 'hello',
              def: 'fdsa'
            }
          end

          it 'does not make any changes' do
            TestConfig.override(max_labels_per_resource: 2)

            expect do
              expect do
                subject
              end.to raise_error(CloudController::Errors::ApiError, /Failed to add 4 labels because it would exceed maximum of 2/)
            end.not_to change { AppLabelModel.count }
          end
        end

        context 'app already has max labels' do
          context 'labels added exceeds max labels' do
            let!(:app_with_labels) do
              AppLabelModel.create(resource_guid: app.guid, key_name: 'release1', value: 'veryunstable')
              AppLabelModel.create(resource_guid: app.guid, key_name: 'release2', value: 'stillunstable')
            end

            let(:labels) do
              {
                release: 'stable',
              }
            end

            it 'does not make any changes' do
              TestConfig.override(max_labels_per_resource: 2)

              expect do
                expect do
                  subject
                end.to raise_error(CloudController::Errors::ApiError, 'Failed to add 1 labels because it would exceed maximum of 2')
              end.not_to change { AppLabelModel.count }
            end
          end
        end

        context 'labels exceed max labels' do
          let!(:app_with_labels) do
            AppLabelModel.create(resource_guid: app.guid, key_name: 'release', value: 'unstable')
            AppLabelModel.create(resource_guid: app.guid, key_name: 'release1', value: 'veryunstable')
            AppLabelModel.create(resource_guid: app.guid, key_name: 'release2', value: 'stillunstable')
            AppLabelModel.create(resource_guid: app.guid, key_name: 'release3', value: 'help')
          end

          context 'deleting old label' do
            let(:labels) do
              {
                release1: nil,
              }
            end

            it 'allows it' do
              TestConfig.override(max_labels_per_resource: 2)
              subject

              expect(AppLabelModel.find(resource_guid: app.guid, key_name: 'release1')).to be_nil
            end
          end

          context 'editing old label' do
            let(:labels) do
              {
                release: 'stable',
              }
            end

            it 'allows it' do
              TestConfig.override(max_labels_per_resource: 2)
              subject

              expect(AppLabelModel.find(resource_guid: app.guid, key_name: 'release').value).to eq 'stable'
            end
          end
        end
      end

      context 'no labels' do
        let(:labels) { nil }

        it 'does not change any labels' do
          expect do
            subject
          end.not_to change { AppLabelModel.count }
        end
      end

      context 'when existing labels are being modified' do
        let(:labels) do
          {
              release: 'stable',
              'joyofcooking.com/potato': 'mashed'
          }
        end

        let!(:old_label) do
          AppLabelModel.create(resource_guid: app.guid, key_name: 'release', value: 'unstable')
        end
        let!(:old_label_with_prefix) do
          AppLabelModel.create(resource_guid: app.guid, key_prefix: 'joyofcooking.com', key_name: 'potato', value: 'fried')
        end

        it 'updates the old label' do
          subject
          expect(old_label.reload.value).to eq 'stable'
          expect(old_label_with_prefix.reload.value).to eq 'mashed'
        end
      end

      context 'deleting labels' do
        let(:labels) do
          {
              release: nil,
              'pre.fix/release': nil,
              nonexistent: nil,
              'joyofcooking.com/potato': 'mashed'
          }
        end

        let!(:delete_me_label) do
          AppLabelModel.create(resource_guid: app.guid, key_name: 'release', value: 'unstable')
        end
        let!(:prefixed_delete_me_label) do
          AppLabelModel.create(resource_guid: app.guid, key_prefix: 'pre.fix', key_name: 'release', value: 'unstable')
        end
        let!(:keep_me_label) do
          AppLabelModel.create(resource_guid: app.guid, key_name: 'potato', value: 'mashed')
        end

        it 'deletes labels that are nil' do
          subject
          expect(AppLabelModel.find(resource_guid: app.guid, key_name: delete_me_label.key_name)).to be_nil
          expect(AppLabelModel.find(resource_guid: app.guid, key_prefix: prefixed_delete_me_label.key_prefix, key_name: prefixed_delete_me_label.key_name)).to be_nil
          expect(keep_me_label.reload.value).to eq 'mashed'
        end

        it 'preserves label keys and sets values to nil when destroy_nil is false' do
          app.db.transaction do
            LabelsUpdate.update(app, labels, AppLabelModel, destroy_nil: false)
          end

          expect(delete_me_label.reload.value).to eq nil
          expect(keep_me_label.reload.value).to eq 'mashed'
        end
      end
    end

    describe 'organization labels' do
      subject(:result) { LabelsUpdate.update(org, labels, OrganizationLabelModel) }

      let(:org) { Organization.make }
      let(:labels) do
        {
            release: 'stable',
            'joyofcooking.com/potato': 'mashed'
        }
      end

      it 'updates the labels' do
        subject
        expect(OrganizationLabelModel.find(resource_guid: org.guid, key_name: 'release').value).to eq 'stable'
        expect(OrganizationLabelModel.find(resource_guid: org.guid, key_prefix: 'joyofcooking.com', key_name: 'potato').value).to eq 'mashed'
      end

      context 'no labels' do
        let(:labels) { nil }

        it 'does not change any labels' do
          expect do
            subject
          end.not_to change { OrganizationLabelModel.count }
        end
      end

      context 'when existing labels are being modified' do
        let(:labels) do
          {
              release: 'stable',
              'joyofcooking.com/potato': 'mashed'
          }
        end

        let!(:old_label) do
          OrganizationLabelModel.create(resource_guid: org.guid, key_name: 'release', value: 'unstable')
        end
        let!(:old_label_with_prefix) do
          OrganizationLabelModel.create(resource_guid: org.guid, key_prefix: 'joyofcooking.com', key_name: 'potato', value: 'fried')
        end

        it 'updates the old label' do
          subject
          expect(old_label.reload.value).to eq 'stable'
          expect(old_label_with_prefix.reload.value).to eq 'mashed'
        end
      end

      context 'deleting labels' do
        let(:labels) do
          {
              release: nil,
              nonexistent: nil,
              'joyofcooking.com/potato': 'mashed'
          }
        end

        let!(:delete_me_label) do
          OrganizationLabelModel.create(resource_guid: org.guid, key_name: 'release', value: 'unstable')
        end
        let!(:keep_me_label) do
          OrganizationLabelModel.create(resource_guid: org.guid, key_name: 'potato', value: 'mashed')
        end

        it 'deletes labels that are nil' do
          subject
          expect(OrganizationLabelModel.find(resource_guid: org.guid, key_name: delete_me_label.key_name)).to be_nil
          expect(keep_me_label.reload.value).to eq 'mashed'
        end
      end
    end
  end
end
