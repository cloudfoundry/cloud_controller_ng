require 'spec_helper'

RSpec.describe HealthCheckPolicy do
  let(:process) { VCAP::CloudController::ProcessModelFactory.make }
  let(:health_check_type) {}
  let(:health_check_timeout) {}
  let(:health_check_invocation_timeout) {}
  let(:health_check_interval) {}
  let(:health_check_http_endpoint) {}

  let(:max_health_check_timeout) { 512 }

  subject(:validator) {
    HealthCheckPolicy.new(process, health_check_timeout, health_check_invocation_timeout, health_check_type, health_check_http_endpoint, health_check_interval)
  }

  describe 'health_check_type' do
    context 'defaults' do
      it 'defaults to port' do
        expect(process.health_check_type).to eq(VCAP::CloudController::HealthCheckTypes::PORT)
      end
    end

    context 'can be set to none' do
      let(:health_check_type) { 'none' }

      it 'does not raise an error' do
        expect(validator).to validate_without_error(process)
      end
    end

    context 'can be set to port' do
      let(:health_check_type) { 'port' }

      it 'does not raise an error' do
        expect(validator).to validate_without_error(process)
      end
    end

    context 'can be set to process' do
      let(:health_check_type) { 'process' }

      it 'does not raise an error' do
        expect(validator).to validate_without_error(process)
      end
    end

    context 'can be set to http' do
      let(:health_check_type) { 'http' }
      let(:health_check_http_endpoint) { '/' }

      it 'does not raise an error' do
        expect(validator).to validate_without_error(process)
      end
    end

    context 'cannot be set to a bogus value' do
      let(:health_check_type) { 'potato' }

      it 'raises an error' do
        expect(validator).to validate_with_error(process, :health_check_type, 'must be one of http, none, port, process')
      end
    end
  end

  describe 'health_check_timeout' do
    before do
      TestConfig.override(maximum_health_check_timeout: max_health_check_timeout)
    end

    context 'when a health_check_timeout exceeds the maximum' do
      let(:health_check_timeout) { 1024 }

      it 'registers error' do
        error_msg = "Maximum exceeded: max #{max_health_check_timeout}s"
        expect(validator).to validate_with_error(process, :health_check_timeout, error_msg)
      end
    end

    context 'when a health_check_timeout is less than zero' do
      let(:health_check_timeout) { -10 }

      it 'registers error' do
        expect(validator).to validate_with_error(process, :health_check_timeout, :less_than_one)
      end
    end

    context 'when a health_check_timeout is zero' do
      let(:health_check_timeout) { 0 }

      it 'registers error' do
        expect(validator).to validate_with_error(process, :health_check_timeout, :less_than_one)
      end
    end

    context 'when a health_check_timeout is greater than zero' do
      let(:health_check_timeout) { 10 }

      it 'does not register error' do
        expect(validator).to validate_without_error(process)
      end
    end

    context 'when a health_check_timeout is nil' do
      let(:health_check_timeout) { nil }

      it 'does not raise an error' do
        expect(validator).to validate_without_error(process)
      end
    end
  end

  describe 'health_check_invocation_timeout' do
    context 'when a health_check_invocation_timeout is less than zero' do
      let(:health_check_invocation_timeout) { -10 }

      it 'registers error' do
        expect(validator).to validate_with_error(process, :health_check_invocation_timeout, :less_than_one)
      end
    end

    context 'when a health_check_invocation_timeout is zero' do
      let(:health_check_invocation_timeout) { 0 }

      it 'registers error' do
        expect(validator).to validate_with_error(process, :health_check_invocation_timeout, :less_than_one)
      end
    end

    context 'when a health_check_invocation_timeout is greater than zero' do
      let(:health_check_invocation_timeout) { 10 }

      it 'does not register error' do
        expect(validator).to validate_without_error(process)
      end
    end
  end

  describe 'health_check_interval' do
    context 'when a health_check_interval is less than zero' do
      let(:health_check_interval) { -10 }

      it 'registers error' do
        expect(validator).to validate_with_error(process, :health_check_interval, :less_than_one)
      end
    end

    context 'when a health_check_interval is zero' do
      let(:health_check_interval) { 0 }

      it 'registers error' do
        expect(validator).to validate_with_error(process, :health_check_interval, :less_than_one)
      end
    end

    context 'when a health_check_interval is greater than zero' do
      let(:health_check_interval) { 10 }

      it 'does not register error' do
        expect(validator).to validate_without_error(process)
      end
    end
  end

  describe 'empty ports and health_check_type' do
    let(:ports) { [] }
    subject(:validator) do
      process.ports = ports
      HealthCheckPolicy.new(process, health_check_timeout, health_check_invocation_timeout, health_check_type, health_check_http_endpoint, health_check_interval)
    end

    describe 'health check type is not "ports"' do
      let(:health_check_type) { VCAP::CloudController::HealthCheckTypes::PROCESS }

      it 'allows empty ports' do
        expect(validator).to validate_without_error(process)
      end
    end

    describe 'health check type is "port"' do
      let(:health_check_type) { VCAP::CloudController::HealthCheckTypes::PORT }

      it 'disallows empty ports' do
        expect(validator).to validate_with_error(process, :ports, 'array cannot be empty when health check type is "port"')
      end
    end

    describe 'health check type is not specified' do
      let(:health_check_type) { nil }

      it 'disallows empty ports' do
        expect(validator).to validate_with_error(process, :ports, 'array cannot be empty when health check type is "port"')
      end
    end
  end

  describe 'health_check_http_endpoint' do
    let(:health_check_type) { VCAP::CloudController::HealthCheckTypes::HTTP }

    context 'set to the root path' do
      let(:health_check_http_endpoint) { '/' }

      it 'validates without errors' do
        expect(validator).to validate_without_error(process)
      end
    end

    context 'set to a valid URI path' do
      let(:health_check_http_endpoint) { '/v2' }

      it 'validates without errors' do
        expect(validator).to validate_without_error(process)
      end
    end

    context 'missing' do
      let(:health_check_http_endpoint) { nil }

      it 'fails validation' do
        error_msg = "HTTP health check endpoint is not a valid URI path: #{health_check_http_endpoint}"
        expect(validator).to validate_with_error(process, :health_check_http_endpoint, error_msg)
      end
    end

    context 'set to a relative path' do
      let(:health_check_http_endpoint) { 'relative/path' }

      it 'fails validation' do
        error_msg = "HTTP health check endpoint is not a valid URI path: #{health_check_http_endpoint}"
        expect(validator).to validate_with_error(process, :health_check_http_endpoint, error_msg)
      end
    end

    context 'set to an empty string' do
      let(:health_check_http_endpoint) { '' }

      it 'fails validation' do
        error_msg = "HTTP health check endpoint is not a valid URI path: #{health_check_http_endpoint}"
        expect(validator).to validate_with_error(process, :health_check_http_endpoint, error_msg)
      end
    end
  end
end
