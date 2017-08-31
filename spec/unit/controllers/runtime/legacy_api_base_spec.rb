require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::LegacyApiBase do
    let(:user) { User.make(admin: true, active: true) }
    let(:logger) { Steno.logger('vcap_spec') }
    let(:fake_req) { '' }

    describe '#has_default_space' do
      it 'should raise NotAuthorized if the user is nil' do
        SecurityContext.set(nil)
        api = LegacyApiBase.new(TestConfig.config_instance, logger, {}, {}, fake_req)
        expect { api.has_default_space? }.to raise_error(CloudController::Errors::ApiError, /not authorized/)
      end

      context 'with app spaces' do
        let(:org) { Organization.make }
        let(:as) { Space.make(organization: org) }
        let(:api) {
          SecurityContext.set(user)
          LegacyApiBase.new(TestConfig.config_instance, logger, {}, {}, fake_req)
        }

        before do
          user.add_organization(org)
        end

        it 'should return true if the user is in atleast one app space and the default_space is not set' do
          user.add_space(as)
          expect(api.has_default_space?).to eq(true)
        end

        it 'should return true if the default app space is set explicitly and the user is not in any app space' do
          user.default_space = as
          expect(api.has_default_space?).to eq(true)
        end

        it 'should return false if the default app space is not set explicitly and the user is not in atleast one app space' do
          expect(api.has_default_space?).to eq(false)
        end
      end
    end

    describe '#default_space' do
      it 'should raise NotAuthorized if the user is nil' do
        SecurityContext.set(nil)
        api = LegacyApiBase.new(TestConfig.config_instance, logger, {}, {}, fake_req)
        expect { api.default_space }.to raise_error(CloudController::Errors::ApiError, /not authorized/)
      end

      it 'should raise LegacyApiWithoutDefaultSpace if the user has no app spaces' do
        SecurityContext.set(user)
        api = LegacyApiBase.new(TestConfig.config_instance, logger, {}, {}, fake_req)
        expect {
          api.default_space
        }.to raise_error(CloudController::Errors::ApiError, /legacy api call requiring a default app space was called/)
      end

      context 'with app spaces' do
        let(:org) { Organization.make }
        let(:as1) { Space.make(organization: org) }
        let(:as2) { Space.make(organization: org) }
        let(:api) {
          SecurityContext.set(user)
          LegacyApiBase.new(TestConfig.config_instance, logger, {}, {}, fake_req)
        }

        before do
          user.add_organization(org)
          user.add_space(as1)
          user.add_space(as2)
        end

        it 'should return the first app space a user is in if default_space is not set' do
          expect(api.default_space).to eq(as1)
          user.remove_space(as1)
          expect(api.default_space).to eq(as2)
        end

        it 'should return the explicitly set default app space if one is set' do
          user.default_space = as2
          expect(api.default_space).to eq(as2)
        end
      end
    end
  end
end
