require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleDataMessage do
    describe 'credentials validation' do
      it 'is valid with proper credentials (username and password)' do
        message = BuildpackLifecycleDataMessage.new({
                                                      stack: 'cflinuxfs4',
                                                      credentials: {
                                                        'docker.io' => {
                                                          'username' => 'user',
                                                          'password' => 'pass'
                                                        }
                                                      }
                                                    })
        expect(message).to be_valid
      end

      it 'is valid with multiple registries' do
        message = BuildpackLifecycleDataMessage.new({
                                                      stack: 'cflinuxfs4',
                                                      credentials: {
                                                        'docker.io' => { 'username' => 'user1', 'password' => 'pass1' },
                                                        'ghcr.io' => { 'username' => 'user2', 'password' => 'pass2' }
                                                      }
                                                    })
        expect(message).to be_valid
      end

      it 'is invalid when credentials value is not a hash' do
        message = BuildpackLifecycleDataMessage.new({
                                                      stack: 'cflinuxfs4',
                                                      credentials: {
                                                        'docker.io' => 'not-a-hash'
                                                      }
                                                    })
        expect(message).not_to be_valid
        expect(message.errors[:credentials]).to include("for registry 'docker.io' must be a hash")
      end

      it 'is invalid when credentials lack username' do
        message = BuildpackLifecycleDataMessage.new({
                                                      stack: 'docker://docker.io/my-org/my-stack:latest',
                                                      credentials: {
                                                        'docker.io' => { 'password' => 'pass' }
                                                      }
                                                    })
        expect(message).not_to be_valid
        expect(message.errors[:credentials]).to include("for registry 'docker.io' must include 'username' and 'password'")
      end

      it 'is invalid when credentials lack password' do
        message = BuildpackLifecycleDataMessage.new({
                                                      stack: 'docker://docker.io/my-org/my-stack:latest',
                                                      credentials: {
                                                        'docker.io' => { 'username' => 'user' }
                                                      }
                                                    })
        expect(message).not_to be_valid
        expect(message.errors[:credentials]).to include("for registry 'docker.io' must include 'username' and 'password'")
      end

      it 'is valid with nil credentials' do
        message = BuildpackLifecycleDataMessage.new({
                                                      stack: 'cflinuxfs4'
                                                    })
        expect(message).to be_valid
      end
    end

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
