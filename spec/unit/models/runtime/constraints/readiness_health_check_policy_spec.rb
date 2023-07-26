require 'spec_helper'

RSpec.describe ReadinessHealthCheckPolicy do
  let(:process) { VCAP::CloudController::ProcessModelFactory.make }
  let(:readiness_health_check_type) {}
  let(:readiness_health_check_invocation_timeout) {}
  let(:readiness_health_check_http_endpoint) {}

  subject(:validator) {
    ReadinessHealthCheckPolicy.new(
      process,
      readiness_health_check_invocation_timeout,
      readiness_health_check_type,
      readiness_health_check_http_endpoint
    )
  }

  describe 'health_check_type' do
    context 'cannot be set to none' do
      let(:readiness_health_check_type) { 'none' }

      it 'raises an error on the correct key' do
        expect(validator).to validate_with_error(process, :readiness_health_check_type, 'must be one of http, port, process')
      end
    end
  end

  describe 'readiness_health_check_invocation_timeout' do
    context 'when there is an error' do
      let(:readiness_health_check_invocation_timeout) { -10 }

      it 'sets the error on the correct key' do
        expect(validator).to validate_with_error(process, :readiness_health_check_invocation_timeout, :less_than_one)
      end
    end
  end

  describe 'readiness_health_check_http_endpoint' do
    context 'when the uri is valid' do
      let(:readiness_health_check_type) { 'http' }
      let(:readiness_health_check_http_endpoint) { '/ready' }

      it 'sets no errors' do
        expect(validator).to validate_without_error(process)
      end
    end

    context 'when there is an error' do
      let(:readiness_health_check_type) { 'http' }
      let(:readiness_health_check_http_endpoint) { 'potato-potahto' }

      it 'sets the error on the correct key' do
        error_msg = "HTTP readiness health check endpoint is not a valid URI path: #{readiness_health_check_http_endpoint}"
        expect(validator).to validate_with_error(process, :readiness_health_check_http_endpoint, error_msg)
      end
    end
  end

  describe 'empty ports and readiness_health_check_type' do
    context 'when there is an error' do
      let(:ports) { [] }
      subject(:validator) do
        process.ports = ports
        ReadinessHealthCheckPolicy.new(process,  readiness_health_check_invocation_timeout, readiness_health_check_type, readiness_health_check_http_endpoint)
      end

      describe 'readiness health check type is not "ports"' do
        let(:readiness_health_check_type) { VCAP::CloudController::HealthCheckTypes::PROCESS }
        let(:readiness_health_check_type) { 'process' }

        it 'allows empty ports' do
          expect(validator).to validate_without_error(process)
        end
      end

      describe 'readiness health check type is "port"' do
        let(:readiness_health_check_type) { VCAP::CloudController::HealthCheckTypes::PORT }

        it 'disallows empty ports' do
          expect(validator).to validate_with_error(process, :ports, 'array cannot be empty when readiness health check type is "port"')
        end
      end

      describe 'readiness health check type is not specified' do
        let(:readiness_health_check_type) { nil }

        it 'allows empty ports' do
          expect(validator).to validate_without_error(process)
        end
      end
    end
  end
end
