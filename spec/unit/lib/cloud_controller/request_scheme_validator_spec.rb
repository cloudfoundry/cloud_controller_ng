require 'spec_helper'
require 'cloud_controller/request_scheme_validator'

module CloudController
  RSpec.describe RequestSchemeValidator do
    let(:validator) { described_class.new }
    let(:user) { double(:user) }
    let(:roles) { double(:roles) }
    let(:config) do
      {
        https_required:            https_required,
        https_required_for_admins: https_required_for_admins,
      }
    end
    let(:request) { double(:request) }

    before do
      allow(roles).to receive(:admin?).and_return(false)
    end

    describe '#validate!' do
      context 'when scheme is http' do
        before do
          allow(request).to receive(:scheme).and_return('http')
        end

        context 'https not required' do
          let(:https_required) { false }
          let(:https_required_for_admins) { false }

          it 'does not raise an error' do
            expect { validator.validate!(user, roles, config, request) }.not_to raise_error
          end

          context 'when there is no user' do
            let(:user) { nil }

            it 'does not raise an error' do
              expect { validator.validate!(user, roles, config, request) }.not_to raise_error
            end
          end

          context 'when there is an admin user' do
            before do
              allow(roles).to receive(:admin?).and_return(true)
            end

            it 'does not raise an error' do
              expect { validator.validate!(user, roles, config, request) }.not_to raise_error
            end
          end
        end

        context 'https is required' do
          let(:https_required) { true }
          let(:https_required_for_admins) { false }

          it 'raises an error' do
            expect { validator.validate!(user, roles, config, request) }.to raise_error(CloudController::Errors::ApiError)
          end

          context 'when there is no user' do
            let(:user) { nil }

            it 'does not raise an error' do
              expect { validator.validate!(user, roles, config, request) }.not_to raise_error
            end
          end

          context 'when there is an admin user' do
            before do
              allow(roles).to receive(:admin?).and_return(true)
            end

            it 'raises an error' do
              expect { validator.validate!(user, roles, config, request) }.to raise_error(CloudController::Errors::ApiError)
            end
          end
        end

        context 'https is required for admins' do
          let(:https_required) { false }
          let(:https_required_for_admins) { true }

          it 'does not raise an error' do
            expect { validator.validate!(user, roles, config, request) }.not_to raise_error
          end

          context 'when there is no user' do
            let(:user) { nil }

            it 'does not raise an error' do
              expect { validator.validate!(user, roles, config, request) }.not_to raise_error
            end
          end

          context 'when there is an admin user' do
            before do
              allow(roles).to receive(:admin?).and_return(true)
            end

            it 'raises an error' do
              expect { validator.validate!(user, roles, config, request) }.to raise_error(CloudController::Errors::ApiError)
            end
          end
        end
      end

      context 'when scheme is https' do
        before do
          allow(request).to receive(:scheme).and_return('https')
        end

        context 'https is required' do
          let(:https_required) { true }
          let(:https_required_for_admins) { false }

          it 'does not raise an error' do
            expect { validator.validate!(user, roles, config, request) }.not_to raise_error
          end

          context 'when there is no user' do
            let(:user) { nil }

            it 'does not raise an error' do
              expect { validator.validate!(user, roles, config, request) }.not_to raise_error
            end
          end

          context 'when there is an admin user' do
            before do
              allow(roles).to receive(:admin?).and_return(true)
            end

            it 'does not raise an error' do
              expect { validator.validate!(user, roles, config, request) }.not_to raise_error
            end
          end
        end

        context 'https is required for admins' do
          let(:https_required) { false }
          let(:https_required_for_admins) { true }

          it 'does not raise an error' do
            expect { validator.validate!(user, roles, config, request) }.not_to raise_error
          end

          context 'when there is no user' do
            let(:user) { nil }

            it 'does not raise an error' do
              expect { validator.validate!(user, roles, config, request) }.not_to raise_error
            end
          end

          context 'when there is an admin user' do
            before do
              allow(roles).to receive(:admin?).and_return(true)
            end

            it 'does not raise an error' do
              expect { validator.validate!(user, roles, config, request) }.not_to raise_error
            end
          end
        end
      end
    end
  end
end
