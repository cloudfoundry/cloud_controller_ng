require 'spec_helper'

RSpec.describe ProcessUserPolicy do
  subject(:validator) { ProcessUserPolicy.new(process, allowed_users) }

  let(:process) { VCAP::CloudController::ProcessModelFactory.make }
  let(:process_user) { 'invalid' }
  let(:allowed_users) { Set.new(%w[vcap ContainerUser]) }

  before do
    # need to stub the user method because validations keep invalid processes from being saved
    allow(process).to receive(:user).and_return(process_user)
  end

  context 'when user is nil' do
    let(:process_user) { nil }

    it 'is valid' do
      expect(validator).to validate_without_error(process)
    end
  end

  context 'when user is empty' do
    let(:process_user) { '' }

    it 'is valid' do
      expect(validator).to validate_without_error(process)
    end
  end

  context 'when user is an allowed user' do
    let(:process_user) { 'ContainerUser' }

    it 'is valid' do
      expect(validator).to validate_without_error(process)
    end
  end

  context 'when user is not an allowed user' do
    let(:process_user) { 'vcarp' }

    it 'is not valid' do
      expect(validator).to validate_with_error(process, :user, sprintf(ProcessUserPolicy::ERROR_MSG, requested_user: "'vcarp'", allowed_users: "'vcap', 'ContainerUser'"))
    end
  end

  describe 'case insensitivity' do
    context 'when user is allowed, but does not match case' do
      let(:process_user) { 'vCaP' }
      let(:allowed_users) { Set.new(['VcAp']) }

      it 'is valid' do
        expect(validator).to validate_without_error(process)
      end
    end
  end
end
