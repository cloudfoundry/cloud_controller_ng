require 'spec_helper'
require_relative '../../app/messages/nested_message_validator'

module VCAP::CloudController
  class IncompleteValidator < NestedMessageValidator
  end

  class CompleteValidator < NestedMessageValidator
    validates :invalid_message, presence: true, allow_nil: false

    def invalid_message
      nil
    end

    def should_validate?
      true
    end

    def error_key
      :data
    end
  end

  class SampleActiveModel
    include ActiveModel::Model
    validates_with CompleteValidator
  end

  RSpec.describe NestedMessageValidator do
    context 'is an abstract interface' do
      describe 'when it is subclassed' do
        let(:incomplete_validator)  { IncompleteValidator.new }
        let(:complete_validator)    { CompleteValidator.new }

        let(:record) { SampleActiveModel.new }

        it 'behaves like an ActiveModel::Validator' do
          expect(complete_validator.is_a?(ActiveModel::Validator)).to eq true
        end

        it 'must override should_validate?' do
          expect { incomplete_validator.validate(record) }.to raise_error /must declare when it should be run/
          expect { complete_validator.validate(record) }.to_not raise_error
        end

        it 'must override error_key' do
          allow(incomplete_validator).to receive(:should_validate?).and_return true
          allow(incomplete_validator).to receive(:valid?).and_return false
          expect { incomplete_validator.validate(record) }.to raise_error /must declare where in record errors should be stored/
          expect { complete_validator.validate(record) }.to_not raise_error
        end

        it 'adds error messages at the specified key on the record that was validated' do
          record.valid?

          expect(record.errors[:data]).to include("Invalid message can't be blank")
        end
      end
    end
  end
end
