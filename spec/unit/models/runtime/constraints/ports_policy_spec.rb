require 'spec_helper'

RSpec.describe PortsPolicy do
  let!(:process) { VCAP::CloudController::ProcessModelFactory.make }
  let(:validator) { PortsPolicy.new(process) }

  context 'invalid processes request' do
    it 'registers error a provided port is not an integer' do
      process.diego = true
      process.ports = [1, 2, 'foo']
      expect(validator).to validate_with_error(process, 'Ports', 'must be integers.')
    end

    it 'registers error if an out of range port is requested' do
      process.diego = true
      process.ports = [1024, 0]
      expect(validator).to validate_with_error(process, 'Ports', 'must be in the 1024-65535 range.')

      process.ports = [1024, -1]
      expect(validator).to validate_with_error(process, 'Ports', 'must be in the 1024-65535 range.')

      process.ports = [1024, 70_000]
      expect(validator).to validate_with_error(process, 'Ports', 'must be in the 1024-65535 range.')

      process.ports = [1024, 1023]
      expect(validator).to validate_with_error(process, 'Ports', 'must be in the 1024-65535 range.')
    end

    it 'registers an error if the ports limit is exceeded' do
      process.diego = true
      process.ports = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
      expect(validator).to validate_with_error(process, 'Process', 'must have at most 10 exposed ports.')
    end
  end

  context 'valid processes' do
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
