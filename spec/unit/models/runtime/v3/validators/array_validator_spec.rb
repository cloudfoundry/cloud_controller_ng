require 'spec_helper'

module VCAP::CloudController::Validators
  describe ArrayValidator do
    class FakeClass
      include ActiveModel::Model
      include VCAP::CloudController::Validators

      validates :field, array: true

      attr_accessor :field
    end

    it 'adds an error if the field is not an array' do
      fake_class = FakeClass.new field: 'not array'
      expect(fake_class.valid?).to be_falsey
      expect(fake_class.errors[:field]).to include 'is not an array'
    end

    it 'does not add an error if the field is an array' do
      fake_class = FakeClass.new field: %w(an array)
      expect(fake_class.valid?).to be_truthy
    end
  end
end
