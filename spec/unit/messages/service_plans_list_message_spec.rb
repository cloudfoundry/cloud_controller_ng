require 'spec_helper'
require 'messages/service_plans_list_message'
require 'field_message_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe ServicePlansListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'available' => 'true',
          'broker_catalog_ids' => 'broker_catalog_id_1,broker_catalog_id_2',
          'include' => 'space.organization,service_offering',
          'names' => 'name_1,name_2',
          'organization_guids' => 'org_guid_1,org_guid_2',
          'service_broker_guids' => 'broker_guid_1,broker_guid_2',
          'service_broker_names' => 'broker_name_1,broker_name_2',
          'service_instance_guids' => 'instance_guid_1,instance_guid_2',
          'service_offering_guids' => 'offering_guid_1,offering_guid_2',
          'service_offering_names' => 'offering_name_1,offering_name_2',
          'space_guids' => 'space_guid_1,space_guid_2',
          'fields' => { 'service_offering.service_broker' => 'guid,name' },
        }.with_indifferent_access
      end

      it 'returns the correct ServicePlansListMessage' do
        message = described_class.from_params(params)

        expect(message).to be_valid
        expect(message).to be_a(ServicePlansListMessage)
        expect(message.available).to eq('true')
        expect(message.broker_catalog_ids).to contain_exactly('broker_catalog_id_1', 'broker_catalog_id_2')
        expect(message.include).to contain_exactly('space.organization', 'service_offering')
        expect(message.names).to contain_exactly('name_1', 'name_2')
        expect(message.organization_guids).to contain_exactly('org_guid_1', 'org_guid_2')
        expect(message.service_broker_guids).to contain_exactly('broker_guid_1', 'broker_guid_2')
        expect(message.service_broker_names).to contain_exactly('broker_name_1', 'broker_name_2')
        expect(message.service_instance_guids).to contain_exactly('instance_guid_1', 'instance_guid_2')
        expect(message.service_offering_guids).to contain_exactly('offering_guid_1', 'offering_guid_2')
        expect(message.service_offering_names).to contain_exactly('offering_name_1', 'offering_name_2')
        expect(message.space_guids).to contain_exactly('space_guid_1', 'space_guid_2')
        expect(message.fields).to match({ 'service_offering.service_broker': ['guid', 'name'] })
      end

      it 'converts requested keys to symbols' do
        message = ServicePlansListMessage.from_params(params)

        expect(message.requested?(:available)).to be_truthy
        expect(message.requested?(:broker_catalog_ids)).to be_truthy
        expect(message.requested?(:include)).to be_truthy
        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:organization_guids)).to be_truthy
        expect(message.requested?(:service_broker_guids)).to be_truthy
        expect(message.requested?(:service_broker_names)).to be_truthy
        expect(message.requested?(:service_instance_guids)).to be_truthy
        expect(message.requested?(:service_offering_guids)).to be_truthy
        expect(message.requested?(:service_offering_names)).to be_truthy
        expect(message.requested?(:space_guids)).to be_truthy
      end

      it 'accepts an empty set' do
        message = described_class.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept arbitrary fields' do
        message = described_class.from_params({ foobar: 'pants' }.with_indifferent_access)

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'available' do
        it 'accepts `true`' do
          message = described_class.from_params({ available: 'true' }.with_indifferent_access)
          expect(message).to be_valid
          expect(message.requested?(:available)).to be_truthy
          expect(message.available).to eq('true')
          expect(message.available?).to be(true)
        end

        it 'accepts `false`' do
          message = described_class.from_params({ available: 'false' }.with_indifferent_access)
          expect(message).to be_valid
          expect(message.requested?(:available)).to be_truthy
          expect(message.available).to eq('false')
          expect(message.available?).to be(false)
        end

        it 'is false by default' do
          message = described_class.from_params({})
          expect(message).to be_valid
          expect(message.requested?(:available)).to be_falsey
          expect(message.available?).to be(false)
        end

        it 'does not accept other values' do
          message = described_class.from_params({ available: 'nope' }.with_indifferent_access)
          expect(message).not_to be_valid
          expect(message.errors[:available]).to include("only accepts values 'true' or 'false'")
        end
      end

      describe 'include' do
        it 'does not accept other values' do
          message = described_class.from_params({ include: 'space' }.with_indifferent_access)
          expect(message).not_to be_valid
          expect(message.errors[:base]).to include(include("Invalid included resource: 'space'"))
        end
      end

      context 'fields' do
        it 'validates `fields` is a hash' do
          message = described_class.from_params({ 'fields' => 'foo' }.with_indifferent_access)
          expect(message).not_to be_valid
          expect(message.errors[:fields][0]).to include('must be an object')
        end

        it_behaves_like 'field query parameter', 'service_offering.service_broker', 'guid,name'

        it 'does not accept fields resources that are not allowed' do
          message = described_class.from_params({ 'fields' => { 'space.foo': 'name' } })
          expect(message).not_to be_valid
          expect(message.errors[:fields]).to include(
            "[space.foo] valid resources are: 'service_offering.service_broker'"
          )
        end
      end
    end
  end
end
