RSpec.shared_examples 'a model including the ServiceOperationMixin' do |service_class, operation_association, operation_class, service_key|
  let(:service) { service_class.make }

  before do
    @service = service
    @operation_association = operation_association
    @operation_class = operation_class
    @service_key = service_key
  end

  def update_operation(type, state)
    @service.last_operation&.destroy
    @operation_class.create({ @service_key => @service.id, type: type, state: state })
    @service.public_send(@operation_association, reload: true)
  end

  describe '#terminal_state?' do
    context 'when there is no operation' do
      it 'returns true' do
        expect(service.terminal_state?).to be true
      end
    end

    context 'when there is an operation' do
      it "returns true for 'succeeded' and 'failed' states" do
        [
          { type: 'create', state: 'initial',     result: false },
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'succeeded',   result: true },
          { type: 'create', state: 'failed',      result: true },
          { type: 'update', state: 'in progress', result: false },
          { type: 'update', state: 'succeeded',   result: true },
          { type: 'update', state: 'failed',      result: true },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: true },
        ].each do |test|
          update_operation(test[:type], test[:state])
          expect(service.terminal_state?).to be test[:result]
        end
      end
    end
  end

  describe '#operation_in_progress?' do
    context 'when there is no operation' do
      it 'returns false' do
        expect(service.operation_in_progress?).to be false
      end
    end

    context 'when there is an operation' do
      it "returns true for 'initial' and 'in progress' states" do
        [
          { type: 'create', state: 'initial',     result: true },
          { type: 'create', state: 'in progress', result: true },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'create', state: 'failed',      result: false },
          { type: 'update', state: 'in progress', result: true },
          { type: 'update', state: 'succeeded',   result: false },
          { type: 'update', state: 'failed',      result: false },
          { type: 'delete', state: 'in progress', result: true },
          { type: 'delete', state: 'failed',      result: false },
        ].each do |test|
          update_operation(test[:type], test[:state])
          expect(service.operation_in_progress?).to be test[:result]
        end
      end
    end
  end

  describe '#create_initial?' do
    context 'when there is no operation' do
      it 'returns false' do
        expect(service.create_initial?).to be false
      end
    end

    context 'when there is an operation' do
      it "returns true only for the 'create initial' state" do
        [
          { type: 'create', state: 'initial',     result: true },
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'create', state: 'failed',      result: false },
          { type: 'update', state: 'in progress', result: false },
          { type: 'update', state: 'succeeded',   result: false },
          { type: 'update', state: 'failed',      result: false },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: false },
        ].each do |test|
          update_operation(test[:type], test[:state])
          expect(service.create_initial?).to be test[:result]
        end
      end
    end
  end

  describe '#create_in_progress?' do
    context 'when there is no operation' do
      it 'returns false' do
        expect(service.create_in_progress?).to be false
      end
    end

    context 'when there is an operation' do
      it "returns true for the 'create initial' and 'create in progress' states" do
        [
          { type: 'create', state: 'initial',     result: true },
          { type: 'create', state: 'in progress', result: true },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'create', state: 'failed',      result: false },
          { type: 'update', state: 'in progress', result: false },
          { type: 'update', state: 'succeeded',   result: false },
          { type: 'update', state: 'failed',      result: false },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: false },
        ].each do |test|
          update_operation(test[:type], test[:state])
          expect(service.create_in_progress?).to be test[:result]
        end
      end
    end
  end

  describe '#create_succeeded?' do
    context 'when there is no operation' do
      it 'returns true' do
        expect(service.create_succeeded?).to be true
      end
    end

    context 'when there is an operation' do
      it "returns true only for the 'create succeeded' state" do
        [
          { type: 'create', state: 'initial',     result: false },
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'succeeded',   result: true },
          { type: 'create', state: 'failed',      result: false },
          { type: 'update', state: 'in progress', result: false },
          { type: 'update', state: 'succeeded',   result: false },
          { type: 'update', state: 'failed',      result: false },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: false },
        ].each do |test|
          update_operation(test[:type], test[:state])
          expect(service.create_succeeded?).to be test[:result]
        end
      end
    end
  end

  describe '#create_failed?' do
    context 'when there is no operation' do
      it 'returns false' do
        expect(service.create_failed?).to be false
      end
    end

    context 'when there is an operation' do
      it "returns true only for the 'create failed' state" do
        [
          { type: 'create', state: 'initial',     result: false },
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'create', state: 'failed',      result: true },
          { type: 'update', state: 'in progress', result: false },
          { type: 'update', state: 'succeeded',   result: false },
          { type: 'update', state: 'failed',      result: false },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: false },
        ].each do |test|
          update_operation(test[:type], test[:state])
          expect(service.create_failed?).to be test[:result]
        end
      end
    end
  end

  describe '#update_in_progress?' do
    context 'when there is no operation' do
      it 'returns false' do
        expect(service.update_in_progress?).to be false
      end
    end

    context 'when there is an operation' do
      it "returns true only for the 'update in progress' state" do
        [
          { type: 'create', state: 'initial',     result: false },
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'create', state: 'failed',      result: false },
          { type: 'update', state: 'in progress', result: true },
          { type: 'update', state: 'succeeded',   result: false },
          { type: 'update', state: 'failed',      result: false },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: false },
        ].each do |test|
          update_operation(test[:type], test[:state])
          expect(service.update_in_progress?).to be test[:result]
        end
      end
    end
  end

  describe '#update_succeeded?' do
    context 'when there is no operation' do
      it 'returns false' do
        expect(service.update_succeeded?).to be false
      end
    end

    context 'when there is an operation' do
      it "returns true only for the 'update succeeded' state" do
        [
          { type: 'create', state: 'initial',     result: false },
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'create', state: 'failed',      result: false },
          { type: 'update', state: 'in progress', result: false },
          { type: 'update', state: 'succeeded',   result: true },
          { type: 'update', state: 'failed',      result: false },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: false },
        ].each do |test|
          update_operation(test[:type], test[:state])
          expect(service.update_succeeded?).to be test[:result]
        end
      end
    end
  end

  describe '#update_failed?' do
    context 'when there is no operation' do
      it 'returns false' do
        expect(service.update_failed?).to be false
      end
    end

    context 'when there is an operation' do
      it "returns true only for the 'update failed' state" do
        [
          { type: 'create', state: 'initial',     result: false },
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'create', state: 'failed',      result: false },
          { type: 'update', state: 'in progress', result: false },
          { type: 'update', state: 'succeeded',   result: false },
          { type: 'update', state: 'failed',      result: true },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: false },
        ].each do |test|
          update_operation(test[:type], test[:state])
          expect(service.update_failed?).to be test[:result]
        end
      end
    end
  end

  describe '#delete_in_progress?' do
    context 'when there is no operation' do
      it 'returns false' do
        expect(service.delete_in_progress?).to be false
      end
    end

    context 'when there is an operation' do
      it "returns true only for the 'delete in progress' state" do
        [
          { type: 'create', state: 'initial',     result: false },
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'create', state: 'failed',      result: false },
          { type: 'update', state: 'in progress', result: false },
          { type: 'update', state: 'succeeded',   result: false },
          { type: 'update', state: 'failed',      result: false },
          { type: 'delete', state: 'in progress', result: true },
          { type: 'delete', state: 'failed',      result: false },
        ].each do |test|
          update_operation(test[:type], test[:state])
          expect(service.delete_in_progress?).to be test[:result]
        end
      end
    end
  end

  describe '#delete_failed?' do
    context 'when there is no operation' do
      it 'returns false' do
        expect(service.delete_failed?).to be false
      end
    end

    context 'when there is an operation' do
      it "returns true only for the 'delete failed' state" do
        [
          { type: 'create', state: 'initial',     result: false },
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'create', state: 'failed',      result: false },
          { type: 'update', state: 'in progress', result: false },
          { type: 'update', state: 'succeeded',   result: false },
          { type: 'update', state: 'failed',      result: false },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: true },
        ].each do |test|
          update_operation(test[:type], test[:state])
          expect(service.delete_failed?).to be test[:result]
        end
      end
    end
  end
end
