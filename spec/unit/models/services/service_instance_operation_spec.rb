require 'spec_helper'

module VCAP::CloudController
  describe ServiceInstanceOperation, type: :model do
    let(:updated_at_time) { Time.now }
    let(:operation_attributes) do
      {
        state: 'in progress',
        description: '50% all the time',
        type: 'create',
        updated_at: updated_at_time
      }
    end

    let(:operation) { ServiceInstanceOperation.make(operation_attributes) }

    describe '#to_hash' do
      it 'includes the type, state, description, and updated at' do
        expect(operation.to_hash).to include({
          'state' => 'in progress',
          'description' => '50% all the time',
          'type' => 'create'
        })

        expect(operation.to_hash['updated_at']).to be
      end
    end
  end
end
