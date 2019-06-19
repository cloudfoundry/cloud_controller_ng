require 'spec_helper'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController::Validators
  RSpec.describe 'LabelSelectorRequirementValidator' do
    let(:label_selector_class) do
      Class.new do
        include ActiveModel::Model
        include VCAP::CloudController::Validators

        attr_accessor :requirements
        validates_with LabelSelectorRequirementValidator
      end
    end
    let(:message) { label_selector_class.new({ requirements: requirements }) }

    context 'when requirements are empty' do
      let(:requirements) { [] }
      it 'fails' do
        expect(message).not_to be_valid
        expect(message.errors_on(:base)).to include('Missing label_selector value')
      end
    end

    context 'when there are no valid requirements' do
      let(:requirements) { [nil, nil, nil] }
      it 'fails' do
        expect(message).not_to be_valid
        expect(message.errors_on(:base)).to include('Invalid label_selector value')
      end
    end

    context 'when the label_selector key is not valid' do
      let(:keys) { %w/v- -v -v- .v v. .v./ }
      let(:requirements) { keys.map { |k| VCAP::CloudController::LabelSelectorRequirement.new(key: k, operator: :equal, values: 'value') } }
      it 'fails' do
        expect(message).not_to be_valid
        keys.each do |key|
          expect(message.errors_on(:base)).to include("'#{key}' starts or ends with invalid characters")
        end
      end
    end

    context 'when the label_selector key is not present' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: '', operator: :equal, values: 'value')] }
      it 'fails' do
        expect(message).not_to be_valid
        expect(message.errors_on(:base)).to include('key cannot be empty string')
      end
    end

    context 'when the in/notin label_selector key has too many slashes' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: 'a/b/c', operator: :equal, values: 'value')] }
      it 'fails' do
        expect(message).not_to be_valid
        expect(message.errors_on(:base)).to include("key has more than one '/'")
      end
    end

    context 'when the key prefix format is invalid' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: 'underscores_not_allowed/foo', operator: :equal, values: 'value')] }
      it 'fails' do
        expect(message).not_to be_valid
        expect(message.errors_on(:base)).to include("prefix 'underscores_not_allowed' must be in valid dns format")
      end
    end

    context 'when the key prefix is not too long' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: 'a.' * (252 / 2) + 'b/foo', operator: :equal, values: 'value')] }
      it 'is valid' do
        expect(message).to be_valid
      end
    end

    context 'when the key prefix is too long' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: 'a.' * (252 / 2) + 'bb/foo', operator: :equal, values: 'value')] }
      it 'fails' do
        expect(message).not_to be_valid
        expect(message.errors_on(:base).first).to include('is greater than 253 characters')
      end
    end

    context 'when the key prefix is reserved' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: 'cloudfoundry.org/foo', operator: :equal, values: 'value')] }
      it 'fails' do
        expect(message).not_to be_valid
        expect(message.errors_on(:base)).to include('prefix \'cloudfoundry.org\' is reserved')
      end
    end

    context 'when the key name is not present' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: 'mangos.com/', operator: :equal, values: 'value')] }
      it 'fails' do
        expect(message).not_to be_valid
        expect(message.errors_on(:base)).to include('key cannot be empty string')
      end
    end

    context 'when the key name contains invalid characters' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: 'mangos.com/<limes>', operator: :equal, values: 'value')] }
      it 'fails' do
        expect(message).not_to be_valid
        expect(message.errors_on(:base)).to include("'<limes>' contains invalid characters")
      end
    end

    context 'when the key name starts or ends with invalid characters' do
      let(:keys) { %w/v- -v -v- .v v. .v./ }
      let(:requirements) { keys.map { |k| VCAP::CloudController::LabelSelectorRequirement.new(key: "mangos.org/#{k}", operator: :equal, values: 'value') } }
      it 'fails' do
        expect(message).not_to be_valid
        keys.each do |key|
          expect(message.errors_on(:base)).to include("'#{key}' starts or ends with invalid characters")
        end
      end
    end

    context 'when the key name is not too long' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: "fish.cows/#{'a' * 63}", operator: :equal, values: 'value')] }
      it 'is valid' do
        expect(message).to be_valid
      end
    end

    context 'when the key name is too long' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: "fish.cows/#{'a' * 64}", operator: :equal, values: 'value')] }
      it 'fails' do
        expect(message).not_to be_valid
        expect(message.errors_on(:base).first).to include('is greater than 63 characters')
      end
    end

    context 'when the value is empty' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: 'horse.badorties', operator: :equal, values: '')] }
      it 'is valid' do
        expect(message).to be_valid
      end
    end

    context 'when the value contains invalid characters' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: 'horse.badorties', operator: :equal, values: '{<neigh>}')] }
      it 'fails' do
        expect(message).not_to be_valid
        expect(message.errors_on(:base).first).to include('contains invalid characters')
      end
    end

    context 'when the value starts or ends with invalid characters' do
      let(:values) { %w/v- -v -v- .v v. .v./ }
      let(:requirements) { values.map { |v| VCAP::CloudController::LabelSelectorRequirement.new(key: 'mangos.org/tangelos', operator: :equal, values: v.to_s) } }
      it 'fails' do
        expect(message).not_to be_valid
        values.each do |value|
          expect(message.errors_on(:base)).to include("'#{value}' starts or ends with invalid characters")
        end
      end
    end

    context 'when the value is not too long' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: 'horse.badorties', operator: :equal, values: 'a' * 63)] }
      it 'is valid' do
        expect(message).to be_valid
      end
    end

    context 'when the value is too long' do
      let(:requirements) { [VCAP::CloudController::LabelSelectorRequirement.new(key: 'horse.badorties', operator: :equal, values: 'a' * 64)] }
      it 'fails' do
        expect(message).not_to be_valid
        expect(message.errors_on(:base).first).to include('is greater than 63 characters')
      end
    end
  end
end
