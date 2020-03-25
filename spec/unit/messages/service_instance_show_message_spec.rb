require 'spec_helper'
require 'messages/service_instance_show_message'

module VCAP::CloudController
  RSpec.describe ServiceInstanceShowMessage do
    it 'accepts the `fields` parameter with `[space.organization]=name,guid`' do
      message = described_class.from_params({ 'fields' => { 'space.organization': 'name,guid' } })
      expect(message).to be_valid
      expect(message.requested?(:fields)).to be_truthy
      expect(message.fields).to match({ 'space.organization': %w(name guid) })
    end

    it 'accepts the `fields` parameter with `[space.organization]=name`' do
      message = described_class.from_params({ 'fields' => { 'space.organization': 'name' } })
      expect(message).to be_valid
      expect(message.requested?(:fields)).to be_truthy
      expect(message.fields).to match({ 'space.organization': %w(name) })
    end

    it 'accepts the `fields` parameter with `[space.organization]=guid`' do
      message = described_class.from_params({ 'fields' => { 'space.organization': 'guid' } })
      expect(message).to be_valid
      expect(message.requested?(:fields)).to be_truthy
      expect(message.fields).to match({ 'space.organization': %w(guid) })
    end

    it 'does not accept fields values that are not `name` or `guid`' do
      message = described_class.from_params({ 'fields' => { 'space.organization': 'name,guid,foo' } })
      expect(message).not_to be_valid
      expect(message.errors[:fields]).to include("valid values are: 'name', 'guid'")
    end

    it 'does not accept fields keys that are not `space.organization`' do
      message = described_class.from_params({ 'fields' => { 'space.foo': 'name' } })
      expect(message).not_to be_valid
      expect(message.errors[:fields]).to include("valid keys are: 'space.organization'")
    end

    it 'does not accept other parameters' do
      message = described_class.from_params({ 'foobar' => 'pants' })
      expect(message).not_to be_valid
      expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
    end
  end
end
