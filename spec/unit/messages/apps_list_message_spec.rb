require 'spec_helper'
require 'messages/apps_list_message'

module VCAP::CloudController
  RSpec.describe AppsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'names' => 'name1,name2',
          'guids' => 'guid1,guid2',
          'organization_guids' => 'orgguid',
          'space_guids' => 'spaceguid',
          'stacks' => 'cflinxfs3',
          'page' => 1,
          'per_page' => 5,
          'order_by' => 'created_at',
          'include' => 'space,space.organization',
          'label_selector' => 'foo in (stuff,things)',
          'lifecycle_type' => 'buildpack',
        }
      end

      it 'returns the correct AppsListMessage' do
        message = AppsListMessage.from_params(params)

        expect(message).to be_a(AppsListMessage)
        expect(message.names).to eq(['name1', 'name2'])
        expect(message.guids).to eq(['guid1', 'guid2'])
        expect(message.organization_guids).to eq(['orgguid'])
        expect(message.space_guids).to eq(['spaceguid'])
        expect(message.stacks).to eq(['cflinxfs3'])
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
        expect(message.include).to eq(['space', 'space.organization'])
        expect(message.label_selector).to eq('foo in (stuff,things)')
        expect(message.requirements.first.key).to eq('foo')
        expect(message.requirements.first.operator).to eq(:in)
        expect(message.requirements.first.values).to contain_exactly('stuff', 'things')
        expect(message.lifecycle_type).to eq('buildpack')
      end

      it 'converts requested keys to symbols' do
        message = AppsListMessage.from_params(params)

        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:guids)).to be_truthy
        expect(message.requested?(:organization_guids)).to be_truthy
        expect(message.requested?(:space_guids)).to be_truthy
        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
        expect(message.requested?(:include)).to be_truthy
        expect(message.requested?(:label_selector)).to be_truthy
        expect(message.requested?(:lifecycle_type)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          names: ['name1', 'name2'],
          guids: ['guid1', 'guid2'],
          organization_guids: ['orgguid1', 'orgguid2'],
          space_guids: ['spaceguid1', 'spaceguid2'],
          page: 1,
          per_page: 5,
          order_by: 'created_at',
          include: ['space', 'space.organization'],
          label_selector: 'foo in (stuff,things)',
          lifecycle_type: 'buildpack'
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:names, :guids, :organization_guids, :space_guids, :include, :label_selector, :lifecycle_type]
        expect(AppsListMessage.from_params(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          AppsListMessage.from_params({
                                names: [],
                                guids: [],
                                organization_guids: [],
                                space_guids: [],
                                page: 1,
                                per_page: 5,
                                order_by: 'created_at',
                                include: ['space', 'space.organization'],
                                label_selector: 'foo in (stuff,things)',
                                lifecycle_type: 'buildpack',
                              })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = AppsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = AppsListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      it 'does not accept include that is not space' do
        message = AppsListMessage.from_params({ 'include' => 'space' })
        expect(message).to be_valid
        message = AppsListMessage.from_params({ 'include' => 'space.organization' })
        expect(message).to be_valid
        message = AppsListMessage.from_params({ 'include' => 'space,space.organization' })
        expect(message).to be_valid
        message = AppsListMessage.from_params({ 'include' => 'greg\'s buildpack' })
        expect(message).not_to be_valid
      end

      describe 'order_by' do
        it 'allows name' do
          message = AppsListMessage.from_params(order_by: 'name')
          expect(message).to be_valid
        end
      end

      describe 'validations' do
        it 'validates names is an array' do
          message = AppsListMessage.from_params names: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:names].length).to eq 1
        end

        it 'validates guids is an array' do
          message = AppsListMessage.from_params guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:guids].length).to eq 1
        end

        it 'validates organization_guids is an array' do
          message = AppsListMessage.from_params organization_guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:organization_guids].length).to eq 1
        end

        it 'validates space_guids is an array' do
          message = AppsListMessage.from_params space_guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:space_guids].length).to eq 1
        end

        it 'validates stacks is an array' do
          message = AppsListMessage.from_params stacks: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:stacks].length).to eq 1
        end

        it 'validates requirements' do
          message = AppsListMessage.from_params('label_selector' => '')

          expect_any_instance_of(Validators::LabelSelectorRequirementValidator).to receive(:validate).with(message).and_call_original
          message.valid?
        end

        it 'validates possible includes' do
          message = AppsListMessage.from_params 'include' => 'space.organization,space'
          expect(message).to be_valid
          message = AppsListMessage.from_params 'include' => 'borg,spaceship'
          expect(message).to be_invalid
          message = AppsListMessage.from_params 'include' => 'space.organization,spaceship'
          expect(message).to be_invalid
        end

        it 'invalidates duplicates in the includes field' do
          message = AppsListMessage.from_params 'include' => 'space.organization,space.organization'
          expect(message).to be_invalid
          expect(message.errors[:base].length).to eq 1
          expect(message.errors[:base][0]).to match(/Duplicate included resource: 'space.organization'/)
        end

        it 'validates lifecycle_type is one of two values' do
          message = AppsListMessage.from_params lifecycle_type: 'not-buildpack-or-docker'
          expect(message).to be_invalid
          expect(message.errors[:base].length).to eq 1
        end

        it 'validates lifecycle_type can be null' do
          message = AppsListMessage.from_params({})
          expect(message).to be_valid
          expect(message.errors[:base].length).to eq 0
        end
      end
    end
  end
end
