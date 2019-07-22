require 'spec_helper'
require 'messages/stack_apps_list_message'

module VCAP::CloudController
  RSpec.describe StackAppsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'names' => 'name1,name2',
          'guids' => 'guid1,guid2',
          'organization_guids' => 'orgguid',
          'space_guids' => 'spaceguid',
          'page' => 1,
          'per_page' => 5,
          'order_by' => 'created_at',
          'include' => 'space,org',
          'label_selector' => 'foo in (stuff,things)',
        }
      end

      it 'returns the correct StackAppsListMessage' do
        message = StackAppsListMessage.from_params(params, stack_name: 'stack-name')

        expect(message).to be_a(StackAppsListMessage)
        expect(message.stacks).to eq(['stack-name'])

        expect(message.names).to eq(['name1', 'name2'])
        expect(message.guids).to eq(['guid1', 'guid2'])
        expect(message.organization_guids).to eq(['orgguid'])
        expect(message.space_guids).to eq(['spaceguid'])
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
        expect(message.include).to eq(['space', 'org'])
        expect(message.label_selector).to eq('foo in (stuff,things)')
        expect(message.requirements.first.key).to eq('foo')
        expect(message.requirements.first.operator).to eq(:in)
        expect(message.requirements.first.values).to contain_exactly('stuff', 'things')
      end
    end
  end
end
