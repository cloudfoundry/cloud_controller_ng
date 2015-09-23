require 'spec_helper'

describe EnableSshPolicy do
  let(:space_allows_ssh) { true }
  let(:ssh_allowed_globally) { true }
  let(:space) { VCAP::CloudController::Space.make(allow_ssh: space_allows_ssh) }
  let(:app) { VCAP::CloudController::AppFactory.make(space: space) }
  let(:ssh_disabled_on_space) { 'must be false due to ssh being disabled on space' }
  let(:ssh_disabled_globally) { 'must be false due to ssh being disabled globally' }
  subject(:validator) { EnableSshPolicy.new(app) }

  before do
    allow(VCAP::CloudController::Config.config).to receive(:[]).with(anything).and_call_original
    allow(VCAP::CloudController::Config.config).to receive(:[]).with(:allow_app_ssh_access).and_return(ssh_allowed_globally)
  end

  context 'when enable_ssh is false' do
    before { app.enable_ssh = false }

    it 'is valid' do
      expect(validator).to validate_without_error(app)
    end
  end

  context 'when enable_ssh is true' do
    before { app.enable_ssh = true }

    context 'when ssh is enabled globally' do
      let(:ssh_allowed_globally) { true }

      context 'when ssh is disabled on the space' do
        let(:space_allows_ssh) { false }

        it 'is invalid' do
          expect(validator).to validate_with_error(app, :enable_ssh, ssh_disabled_on_space)
        end
      end

      context 'when ssh is enabled on the space' do
        let(:space_allows_ssh) { true }

        it 'is valid' do
          expect(validator).to validate_without_error(app)
        end

        context 'when ssh is later disabled on the space' do
          before do
            space.allow_ssh = false
            space.save
          end

          it 'is valid' do
            expect(validator).to validate_without_error(app)
          end

          context 'when ssh_enabled is then flipped on the app' do
            before do
              app.enable_ssh = false
              app.save
              expect(validator).to validate_without_error(app)

              app.enable_ssh = true
            end

            it 'is invalid' do
              expect(validator).to validate_with_error(app, :enable_ssh, ssh_disabled_on_space)
            end
          end
        end
      end
    end

    context 'when ssh is disabled globally' do
      let(:ssh_allowed_globally) { false }

      it 'is invalid' do
        expect(validator).to validate_with_error(app, :enable_ssh, ssh_disabled_globally)
      end
    end
  end
end
