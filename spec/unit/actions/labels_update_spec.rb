require 'spec_helper'
require 'actions/labels_update'

module VCAP::CloudController
  RSpec.describe LabelsUpdate do
    describe 'apps labels' do
      subject(:result) { LabelsUpdate.update(app, labels, AppLabelModel) }

      let(:app) { AppModel.make }
      let(:labels) do
        {
            release: 'stable',
            'joyofcooking.com/potato': 'mashed'
        }
      end

      it 'updates the labels' do
        subject
        expect(AppLabelModel.find(app_guid: app.guid, key_name: 'release').value).to eq 'stable'
        expect(AppLabelModel.find(app_guid: app.guid, key_prefix: 'joyofcooking.com', key_name: 'potato').value).to eq 'mashed'
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
          AppLabelModel.create(app_guid: app.guid, key_name: 'release', value: 'unstable')
        end
        let!(:old_label_with_prefix) do
          AppLabelModel.create(app_guid: app.guid, key_prefix: 'joyofcooking.com', key_name: 'potato', value: 'fried')
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
          AppLabelModel.create(app_guid: app.guid, key_name: 'release', value: 'unstable')
        end
        let!(:keep_me_label) do
          AppLabelModel.create(app_guid: app.guid, key_name: 'potato', value: 'mashed')
        end

        it 'deletes labels that are nil' do
          subject
          expect(AppLabelModel.find(app_guid: app.guid, key_name: delete_me_label.key_name)).to be_nil
          expect(keep_me_label.reload.value).to eq 'mashed'
        end
      end
    end

    describe 'orgs labels' do
      subject(:result) { LabelsUpdate.update(org, labels, OrgLabelModel) }

      let(:org) { Organization.make }
      let(:labels) do
        {
            release: 'stable',
            'joyofcooking.com/potato': 'mashed'
        }
      end

      it 'updates the labels' do
        subject
        expect(OrgLabelModel.find(org_guid: org.guid, key_name: 'release').value).to eq 'stable'
        expect(OrgLabelModel.find(org_guid: org.guid, key_prefix: 'joyofcooking.com', key_name: 'potato').value).to eq 'mashed'
      end

      context 'no labels' do
        let(:labels) { nil }

        it 'does not change any labels' do
          expect do
            subject
          end.not_to change { OrgLabelModel.count }
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
          OrgLabelModel.create(org_guid: org.guid, key_name: 'release', value: 'unstable')
        end
        let!(:old_label_with_prefix) do
          OrgLabelModel.create(org_guid: org.guid, key_prefix: 'joyofcooking.com', key_name: 'potato', value: 'fried')
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
          OrgLabelModel.create(org_guid: org.guid, key_name: 'release', value: 'unstable')
        end
        let!(:keep_me_label) do
          OrgLabelModel.create(org_guid: org.guid, key_name: 'potato', value: 'mashed')
        end

        it 'deletes labels that are nil' do
          subject
          expect(OrgLabelModel.find(org_guid: org.guid, key_name: delete_me_label.key_name)).to be_nil
          expect(keep_me_label.reload.value).to eq 'mashed'
        end
      end
    end
  end
end
