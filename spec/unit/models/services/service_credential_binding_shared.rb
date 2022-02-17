RSpec.shared_examples 'a model including the ServiceCredentialBindingMixin' do |service_credential_binding_class, operation_class, operation_association|
  let(:service_credential_binding) { service_credential_binding_class.make }
  let(:operation) { operation_class.make(state: state) }

  before do
    service_credential_binding.associations[operation_association] = operation
  end

  describe '#terminal_state?' do
    context 'when state is succeeded' do
      let(:state) { 'succeeded' }

      it 'returns true' do
        expect(service_credential_binding.terminal_state?).to be true
      end
    end

    context 'when state is failed' do
      let(:state) { 'failed' }

      it 'returns true' do
        expect(service_credential_binding.terminal_state?).to be true
      end
    end

    context 'when state is something else' do
      let(:state) { 'in progress' }

      it 'returns false' do
        expect(service_credential_binding.terminal_state?).to be false
      end
    end

    context 'when binding operation is missing' do
      let(:operation) { nil }

      it 'returns true' do
        expect(service_credential_binding.terminal_state?).to be true
      end
    end
  end

  describe '#operation_in_progress?' do
    context 'when the service credential binding has been created synchronously' do
      let(:operation) { nil }

      it 'returns false' do
        expect(service_credential_binding.operation_in_progress?).to be false
      end
    end

    context 'when the service credential binding is being created asynchronously' do
      context 'and the operation is in progress' do
        let(:state) { 'in progress' }

        it 'returns true' do
          expect(service_credential_binding.operation_in_progress?).to be true
        end
      end

      context 'and the operation has failed' do
        let(:state) { 'failed' }

        it 'returns false' do
          expect(service_credential_binding.operation_in_progress?).to be false
        end
      end

      context 'and the operation has succeeded' do
        let(:state) { 'succeeded' }

        it 'returns false' do
          expect(service_credential_binding.operation_in_progress?).to be false
        end
      end
    end
  end

  describe '#create_succeeded?' do
    let(:operation) { nil }

    context 'when there is no binding operation' do
      it 'returns true' do
        expect(service_credential_binding.create_succeeded?).to be true
      end
    end

    context 'when there is a binding operation' do
      it "returns true only for the 'create succeeded' state" do
        [
          { type: 'create', state: 'failed',      result: false },
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'succeeded',   result: true },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: false },
          { type: 'delete', state: 'succeeded',   result: false },
        ].each do |test|
          service_credential_binding.save_with_attributes_and_new_operation({}, { type: test[:type], state: test[:state] })

          expect(service_credential_binding.create_succeeded?).to be test[:result]
        end
      end
    end
  end

  describe '#create_failed?' do
    let(:operation) { nil }

    context 'when there is no binding operation' do
      it 'returns false' do
        expect(service_credential_binding.create_failed?).to be false
      end
    end

    context 'when there is a binding operation' do
      it "returns true only for the 'create failed' state" do
        [
          { type: 'create', state: 'failed',      result: true },
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: false },
          { type: 'delete', state: 'succeeded',   result: false },
        ].each do |test|
          service_credential_binding.save_with_attributes_and_new_operation({}, { type: test[:type], state: test[:state] })

          expect(service_credential_binding.create_failed?).to be test[:result]
        end
      end
    end
  end

  describe '#create_in_progress?' do
    let(:operation) { nil }

    context 'when there is no binding operation' do
      it 'returns false' do
        expect(service_credential_binding.create_in_progress?).to be false
      end
    end

    context 'when there is a binding operation' do
      it "returns true only for the 'create in progress' state" do
        [
          { type: 'create', state: 'in progress', result: true },
          { type: 'create', state: 'failed',      result: false },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: false },
          { type: 'delete', state: 'succeeded',   result: false },
        ].each do |test|
          service_credential_binding.save_with_attributes_and_new_operation({}, { type: test[:type], state: test[:state] })

          expect(service_credential_binding.create_in_progress?).to be test[:result]
        end
      end
    end
  end

  describe '#delete_failed?' do
    let(:operation) { nil }

    context 'when there is no binding operation' do
      it 'returns false' do
        expect(service_credential_binding.delete_failed?).to be false
      end
    end

    context 'when there is a binding operation' do
      it "returns true only for the 'delete failed' state" do
        [
          { type: 'create', state: 'failed',      result: false },
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'delete', state: 'in progress', result: false },
          { type: 'delete', state: 'failed',      result: true },
          { type: 'delete', state: 'succeeded',   result: false },
        ].each do |test|
          service_credential_binding.save_with_attributes_and_new_operation({}, { type: test[:type], state: test[:state] })

          expect(service_credential_binding.delete_failed?).to be test[:result]
        end
      end
    end
  end

  describe '#delete_in_progress?' do
    let(:operation) { nil }

    context 'when there is no binding operation' do
      it 'returns false' do
        expect(service_credential_binding.delete_in_progress?).to be false
      end
    end

    context 'when there is a binding operation' do
      it "returns true only for the 'delete in progress' state" do
        [
          { type: 'create', state: 'in progress', result: false },
          { type: 'create', state: 'failed',      result: false },
          { type: 'create', state: 'succeeded',   result: false },
          { type: 'delete', state: 'in progress', result: true },
          { type: 'delete', state: 'failed',      result: false },
          { type: 'delete', state: 'succeeded',   result: false },
        ].each do |test|
          service_credential_binding.save_with_attributes_and_new_operation({}, { type: test[:type], state: test[:state] })

          expect(service_credential_binding.delete_in_progress?).to be test[:result]
        end
      end
    end
  end
end
