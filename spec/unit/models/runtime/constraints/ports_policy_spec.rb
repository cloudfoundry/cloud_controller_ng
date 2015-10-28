require 'spec_helper'

describe PortsPolicy do
  let!(:app) { VCAP::CloudController::AppFactory.make }
  let(:validator) { PortsPolicy.new(app) }

  context 'invalid apps' do
    it 'registers error a provided port is not an integer' do
      app.ports = [1, 2, 'foo']
      expect(validator).to validate_with_error(app, :ports, 'must be integers')
    end

    it 'registers error if an out of range port is requested' do
      app.ports = [500, 0]
      expect(validator).to validate_with_error(app, :ports, 'must be in valid port range')

      app.ports = [500, -1]
      expect(validator).to validate_with_error(app, :ports, 'must be in valid port range')

      app.ports = [500, 70_000]
      expect(validator).to validate_with_error(app, :ports, 'must be in valid port range')
    end
  end

  context 'valid apps' do
    it 'does not require ports' do
      expect(app.valid?).to eq(true)
    end

    it 'does not register error if valid ports are requested' do
      app.ports = [500, 600, 65535]
      expect(validator).to validate_without_error(app)
    end
  end
end
