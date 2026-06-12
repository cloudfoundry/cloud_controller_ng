require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleDataMessage do
    describe 'stack_id field' do
      it 'is valid with a stack_id' do
        message = BuildpackLifecycleDataMessage.new({
                                                      stack: 'docker://docker.io/cloudfoundry/cflinuxfs4:1.0.0',
                                                      stack_id: 'io.buildpacks.stacks.jammy'
                                                    })
        expect(message).to be_valid
      end

      it 'is valid without a stack_id' do
        message = BuildpackLifecycleDataMessage.new({
                                                      stack: 'cflinuxfs4'
                                                    })
        expect(message).to be_valid
      end

      it 'is invalid with a too-long stack_id' do
        message = BuildpackLifecycleDataMessage.new({
                                                      stack: 'cflinuxfs4',
                                                      stack_id: 'a' * 4097
                                                    })
        expect(message).not_to be_valid
      end
    end

    describe 'custom stack URI as stack value' do
      it 'accepts a docker:// URI as stack value' do
        message = BuildpackLifecycleDataMessage.new({
                                                      stack: 'docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0',
                                                      buildpacks: ['https://github.com/my-org/my-buildpack.git']
                                                    })
        expect(message).to be_valid
      end
    end
  end
end
