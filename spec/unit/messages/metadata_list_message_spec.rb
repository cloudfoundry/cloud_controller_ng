require 'spec_helper'
require 'messages/metadata_list_message'

module VCAP::CloudController
  RSpec.describe MetadataListMessage do
    let(:fake_class) do
      Class.new(MetadataListMessage) do
        register_allowed_keys []
      end
    end

    subject do
      fake_class.from_params(params, [])
    end

    context 'when given a valid label_selector' do
      let(:params) { { 'label_selector' => '!fruit,env=prod,animal in (dog,horse)' } }

      it 'is valid' do
        expect(subject).to be_valid
      end

      it 'can return label_selector' do
        expect(subject.label_selector).to eq('!fruit,env=prod,animal in (dog,horse)')
      end
    end

    context 'when given an invalid label_selector' do
      let(:params) { { 'label_selector' => '' } }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:base]).to include('Missing label_selector value')
      end
    end
  end
end
