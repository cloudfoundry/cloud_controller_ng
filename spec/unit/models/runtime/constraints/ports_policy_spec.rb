require 'spec_helper'

RSpec.describe PortsPolicy do
  let!(:process) { VCAP::CloudController::ProcessModelFactory.make }
  let(:validator) { PortsPolicy.new(process, changed_to_diego) }
  let(:changed_to_diego) { false }

  context 'invalid apps request' do
    it 'registers error a provided port is not an integer' do
      process.diego = true
      process.ports = [1, 2, 'foo']
      expect(validator).to validate_with_error(process, :ports, 'must be integers')
    end

    it 'registers error if an out of range port is requested' do
      process.diego = true
      process.ports = [1024, 0]
      expect(validator).to validate_with_error(process, :ports, 'Ports must be in the 1024-65535.')

      process.ports = [1024, -1]
      expect(validator).to validate_with_error(process, :ports, 'Ports must be in the 1024-65535.')

      process.ports = [1024, 70_000]
      expect(validator).to validate_with_error(process, :ports, 'Ports must be in the 1024-65535.')

      process.ports = [1024, 1023]
      expect(validator).to validate_with_error(process, :ports, 'Ports must be in the 1024-65535.')
    end

    it 'registers an error if the ports limit is exceeded' do
      process.diego = true
      process.ports = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
      expect(validator).to validate_with_error(process, :ports, 'Maximum of 10 app ports allowed.')
    end
  end

  context 'non diego apps' do
    context 'when ports are not nil' do
      it 'registers error that custom ports cannot be specified for non diego apps' do
        process.diego = false
        process.ports = [1, 2]
        expect(validator).to validate_with_error(process, :ports, 'Custom app ports supported for Diego only. Enable Diego for the app or remove custom app ports.')
      end
    end

    context 'when ports are nil' do
      it 'does not register error' do
        process.diego = false
        expect(process.valid?).to eq(true)
      end
    end

    context 'when ports are empty' do
      before do
        process.health_check_type = 'process'
      end

      it 'does not register error' do
        process.diego = false
        process.ports = []
        expect(process.valid?).to eq(true)
      end
    end
  end

  context 'valid apps' do
    it 'does not require ports' do
      expect(process.valid?).to eq(true)
    end

    it 'does not register error if valid ports are requested' do
      process.diego = true
      process.ports = [2000, 3000, 65535]
      expect(validator).to validate_without_error(process)
    end
  end
end
