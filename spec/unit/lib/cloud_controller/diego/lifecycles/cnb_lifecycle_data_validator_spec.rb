require 'spec_helper'
require 'cloud_controller/diego/lifecycles/cnb_lifecycle_data_validator'

module VCAP::CloudController
  RSpec.describe CNBLifecycleDataValidator do
    describe 'rejects userinfo embedded in a CNB buildpack URL' do
      let(:cnb_url_with_creds) { BuildpackInfo.new('https://user:pass@example.org/buildpack.git', nil) }
      let(:cnb_url_clean)      { BuildpackInfo.new('https://example.org/buildpack.git', nil) }

      context 'when a CNB buildpack URL has userinfo' do
        it 'is not valid regardless of credentials' do
          validator = CNBLifecycleDataValidator.new(
            buildpack_infos: [cnb_url_with_creds],
            stack: create(:stack),
            credentials: nil
          )
          expect(validator).not_to be_valid
          expect(validator.errors.full_messages.join).to match(/CNB.*credentials|credentials.*CNB/i)
        end
      end

      context 'when a CNB buildpack URL is clean' do
        it 'is valid' do
          validator = CNBLifecycleDataValidator.new(
            buildpack_infos: [cnb_url_clean],
            stack: create(:stack),
            credentials: { 'example.org' => { 'username' => 'u', 'password' => 'p' } }
          )
          expect(validator).to be_valid
        end
      end
    end
  end
end
