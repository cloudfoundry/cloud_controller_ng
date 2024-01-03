require 'spec_helper'
require 'actions/label_delete'

module VCAP::CloudController
  RSpec.describe LabelDelete do
    subject(:label_delete) { LabelDelete }

    describe '#delete' do
      let!(:app) { AppModel.make }
      let!(:label) { AppLabelModel.make(resource_guid: app.guid, key_name: 'test1', value: 'bommel') }
      let!(:label2) { AppLabelModel.make(resource_guid: app.guid, key_name: 'test2', value: 'bommel') }

      it 'deletes and cancels the label' do
        label_delete.delete([label, label2])

        expect(label.exists?).to be(false), 'Expected label to not exist, but it does'
        expect(label2.exists?).to be(false), 'Expected label2 to not exist, but it does'
      end
    end
  end
end
