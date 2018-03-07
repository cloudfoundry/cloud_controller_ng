require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceBindingOperation, type: :model do
    let(:updated_at_time) { Time.now }
    let(:created_at_time) { Time.now }
    let(:operation_attributes) do
      {
        state: 'in progress',
        description: '10%',
      }
    end

    let(:operation) { ServiceBindingOperation.make(operation_attributes) }
    before do
      operation.this.update(updated_at: updated_at_time, created_at: created_at_time)
      operation.reload
    end

    describe '#to_hash' do
      it 'includes the state, description and updated at' do
        expect(operation.to_hash).to include({
          'state' => 'in progress',
          'description' => '10%',
        })

        expect(operation.to_hash['updated_at'].to_i).to eq(updated_at_time.to_i)
        expect(operation.to_hash['created_at'].to_i).to eq(created_at_time.to_i)
      end
    end

    describe 'updating attributes' do
      it 'updates the attributes of the service instance operation' do
        new_attributes = {
          state: 'finished',
          description: '100%'
        }
        operation.update_attributes(new_attributes)
        expect(operation.state).to eq 'finished'
        expect(operation.description).to eq '100%'
      end
    end
  end
end
