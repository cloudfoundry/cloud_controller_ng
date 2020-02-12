require 'spec_helper'
require 'messages/service_plan_visibility_update_message'

module VCAP::CloudController
  RSpec.describe ServicePlanVisibilityUpdateMessage do
    let(:subject) { ServicePlanVisibilityUpdateMessage }
    describe '.from_params' do
      let(:params) { { 'type' => 'public' }.with_indifferent_access }

      it 'errors with invalid keys' do
        message = subject.from_params({ foobar: 'pants' }.with_indifferent_access)

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end

      it 'errors with an empty set' do
        message = subject.from_params({})
        expect(message).not_to be_valid
        expect(message.errors[:type]).to include("Type must be one of 'public', 'admin', 'organization'")
      end

      it 'converts requested keys to symbols' do
        message = subject.from_params(params)
        expect(message.requested?(:type)).to be_truthy
      end

      it 'returns the correct message' do
        message = subject.from_params({ 'type' => 'public' })

        expect(message).to be_valid
        expect(message).to be_a(ServicePlanVisibilityUpdateMessage)
        expect(message.type).to eq('public')
      end

      context 'values for `type`' do
        it 'accepts `public`' do
          message = subject.from_params({ 'type' => 'public' })

          expect(message).to be_valid
          expect(message.type).to eq('public')
        end

        it 'accepts `admin`' do
          message = subject.from_params({ 'type' => 'admin' })

          expect(message).to be_valid
          expect(message.type).to eq('admin')
        end

        it 'accepts `organization`' do
          message = subject.from_params({ 'type' => 'organization' })

          expect(message).to be_valid
          expect(message.type).to eq('organization')
        end

        it 'does not accept other values' do
          message = subject.from_params({ 'type' => 'space' })

          expect(message).not_to be_valid
          expect(message.errors[:type]).to include("Type must be one of 'public', 'admin', 'organization'")
        end
      end
    end
  end
end
