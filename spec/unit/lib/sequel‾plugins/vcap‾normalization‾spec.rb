require 'spec_helper'

RSpec.describe 'Sequel::Plugins::VcapNormalization' do
  class TestModel < Sequel::Model
    plugin :vcap_normalization
    strip_attributes :unique_value
  end

  describe '.strip_attributes' do
    it 'should only result in provided strings being normalized' do
      model_object = TestModel.new
      model_object.guid = ' hi '
      model_object.unique_value = ' bye '
      expect(model_object.guid).to eq ' hi '
      expect(model_object.unique_value).to eq 'bye'
    end
  end
end
