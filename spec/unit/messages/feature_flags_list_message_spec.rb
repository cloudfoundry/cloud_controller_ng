require 'spec_helper'
require 'messages/feature_flags_list_message'

module VCAP::CloudController
  RSpec.describe FeatureFlagsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'order_by' => '-name',
        }
      end

      it 'returns the correct FeatureFLagsListMessage' do
        message = FeatureFlagsListMessage.from_params(params)

        expect(message).to be_a(FeatureFlagsListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('-name')
      end
    end

    describe 'pagination options' do
      it 'defaults order_by to name' do
        message = FeatureFlagsListMessage.from_params({})

        expect(message.pagination_options.order_by).to eq('name')
      end

      it 'maintains an empty order by in the url when using the default' do
        message = FeatureFlagsListMessage.from_params({})

        expect(message.pagination_options.order_by).to eq('name')
      end

      it 'allows order_by to be overridden' do
        message = FeatureFlagsListMessage.from_params({ 'order_by' => '-name' })

        expect(message.pagination_options.order_by).to eq('name')
        expect(message.pagination_options.order_direction).to eq('desc')
      end
    end

    describe 'validations' do
      it 'is valid with pagination options' do
        message = FeatureFlagsListMessage.from_params({ page: 1, per_page: 5, order_by: '-name' })
        expect(message).to be_valid
      end

      it 'is invalid with extra params' do
        message = FeatureFlagsListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      it 'validates that order_by value is in the supported list' do
        message = FeatureFlagsListMessage.from_params order_by: 'created_at'
        expect(message).to be_invalid
        expect(message.errors[:order_by].length).to eq 1
      end

      it 'validates that created_ats is invalid' do
        message = FeatureFlagsListMessage.from_params({ created_ats: 'created_at' })
        expect(message).to be_invalid
        expect(message.errors[:base][0]).to eq "Filtering by 'created_ats' is not allowed on this resource."
      end
    end
  end
end
