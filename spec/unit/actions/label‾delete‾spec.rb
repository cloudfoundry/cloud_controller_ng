require 'spec_helper'
require 'actions/label_delete'

module VCAP::CloudController
  RSpec.describe LabelDelete do
    subject(:label_delete) { LabelDelete }

    describe '#delete' do
      let!(:label) { AppLabelModel.make }
      let!(:label2) { AppLabelModel.make }

      it 'deletes and cancels the label' do
        label_delete.delete([label, label2])

        expect(label.exists?).to eq(false), 'Expected label to not exist, but it does'
        expect(label2.exists?).to eq(false), 'Expected label2 to not exist, but it does'
      end
    end
  end
end
