require 'spec_helper'
require 'securerandom'

describe 'Sequel::Plugins::VcapSerialization' do
  class TestModel < Sequel::Model
    import_attributes :guid, :required_attr
  end

  describe '#create_from_hash' do
    it 'should succeed when setting only allowed values' do
      m = TestModel.create_from_hash guid: '1', required_attr: true
      expect(m.guid).to eq('1')
      expect(m.required_attr).to eq(true)
    end

    it 'should not set attributes not marked for import' do
      m = TestModel.create_from_hash guid: '1', unique_value: 'unique', required_attr: true
      expect(m.guid).to eq('1')
      expect(m.unique_value).to eq(nil)
      expect(m.required_attr).to eq(true)
    end
  end

  describe '#create_from_json' do
    it 'should succeed when setting only allowed values' do
      json = MultiJson.dump guid: '1', required_attr: true
      m = TestModel.create_from_json json
      expect(m.guid).to eq('1')
      expect(m.required_attr).to eq(true)
    end

    it 'should not set attributes not marked for import' do
      json = MultiJson.dump guid: '1', unique_value: 'unique', required_attr: true
      m = TestModel.create_from_json json
      expect(m.guid).to eq('1')
      expect(m.unique_value).to eq(nil)
      expect(m.required_attr).to eq(true)
    end
  end

  describe '#update_from_json' do
    let!(:instance) { TestModel.create(guid: '1', required_attr: true, unique_value: 'unique') }

    it 'should succeed when setting only allowed values' do
      json = MultiJson.dump guid: '2'
      instance.update_from_json json
      expect(instance.guid).to eq('2')
    end

    it 'should not set attributes not marked for import' do
      json = MultiJson.dump guid: '2', unique_value: 'other_unique'
      instance.update_from_json json
      expect(instance.guid).to eq('2')
      expect(instance.unique_value).to eq('unique')
    end
  end

  describe '#to_hash' do
    context 'when the instance defines different attributes to export' do
      class TestModel < Sequel::Model
        def export_attrs
          super + [:required_attr]
        end
      end

      it 'uses the attributes defined by the instance' do
        hash = TestModel.new.to_hash
        expect(hash.keys).to eq(['required_attr'])
      end
    end
  end
end
