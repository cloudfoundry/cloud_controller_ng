require 'spec_helper'
require 'cloud_controller/diego/custom_stack_uri_converter'

module VCAP::CloudController
  module Diego
    RSpec.describe CustomStackUriConverter do
      describe '.convert' do
        it 'converts docker://host/path:tag to Diego rootfs format' do
          result = CustomStackUriConverter.convert('docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0')
          expect(result).to eq('docker://docker.io/cloudfoundry/cflinuxfs4#1.268.0')
        end

        it 'converts docker://host/path without tag (no fragment appended)' do
          result = CustomStackUriConverter.convert('docker://docker.io/cloudfoundry/cflinuxfs4')
          expect(result).to eq('docker://docker.io/cloudfoundry/cflinuxfs4')
        end

        it 'handles private registries' do
          result = CustomStackUriConverter.convert('docker://registry.example.com/my-org/my-stack:v2.0')
          expect(result).to eq('docker://registry.example.com/my-org/my-stack#v2.0')
        end

        it 'handles images without explicit registry (docker hub shorthand)' do
          result = CustomStackUriConverter.convert('docker://ubuntu:22.04')
          expect(result).to eq('docker:///library/ubuntu#22.04')
        end

        it 'handles digest references' do
          digest = 'sha256:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'
          result = CustomStackUriConverter.convert("docker://docker.io/cloudfoundry/cflinuxfs4@#{digest}")
          expect(result).to include('docker://docker.io/cloudfoundry/cflinuxfs4')
        end
      end
    end
  end
end
