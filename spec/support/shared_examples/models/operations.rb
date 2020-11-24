RSpec.shared_examples 'operation' do
  let(:updated_at_time) { Time.utc(2018, 5, 2, 3, 30, 0) }
  let(:created_at_time) { Time.utc(2018, 5, 2, 3, 30, 0) }
  let(:operation_attributes) do
    {
      state: 'in progress',
      description: '10%',
      type: 'create',
    }
  end

  let(:operation) { described_class.make(operation_attributes) }

  before do
    operation.this.update(updated_at: updated_at_time, created_at: created_at_time)
    operation.reload
  end

  describe '#to_hash' do
    it 'includes the state, type, description, created_at and updated_at' do
      expect(operation.to_hash).to include({
        'state' => 'in progress',
        'type' => 'create',
        'description' => '10%',
      })

      expect(operation.to_hash['updated_at']).to eq(updated_at_time)
      expect(operation.to_hash['created_at']).to eq(created_at_time)
    end
  end

  describe 'updating attributes' do
    it 'updates the attributes of the operation' do
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
