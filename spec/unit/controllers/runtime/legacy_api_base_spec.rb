require 'spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::LegacyApiBase do
    let(:user) { User.make(admin: true, active: true) }
    let(:logger) { Steno.logger('vcap_spec') }
    let(:fake_req) { '' }
    let(:dependencies) do
      {
        statsd_client: double(Statsd)
      }
    end

    describe '#has_default_space' do
      it 'raises NotAuthorized if the user is nil' do
        SecurityContext.set(nil)
        api = LegacyApiBase.new(TestConfig.config_instance, logger, {}, {}, fake_req, nil, dependencies)
        expect { api.has_default_space? }.to raise_error(CloudController::Errors::ApiError, /not authorized/)
      end

      context 'with app spaces' do
        let(:org) { Organization.make }
        let(:as) { Space.make(organization: org) }
        let(:api) do
          SecurityContext.set(user)
          LegacyApiBase.new(TestConfig.config_instance, logger, {}, {}, fake_req, nil, dependencies)
        end

        before do
          user.add_organization(org)
        end

        it 'returns true if the user is in atleast one app space and the default_space is not set' do
          user.add_space(as)
          expect(api.has_default_space?).to be(true)
        end

        it 'returns true if the default app space is set explicitly and the user is not in any app space' do
          user.default_space = as
          expect(api.has_default_space?).to be(true)
        end

        it 'returns false if the default app space is not set explicitly and the user is not in atleast one app space' do
          expect(api.has_default_space?).to be(false)
        end
      end
    end

    describe '#default_space' do
      it 'raises NotAuthorized if the user is nil' do
        SecurityContext.set(nil)
        api = LegacyApiBase.new(TestConfig.config_instance, logger, {}, {}, fake_req, nil, dependencies)
        expect { api.default_space }.to raise_error(CloudController::Errors::ApiError, /not authorized/)
      end

      it 'raises LegacyApiWithoutDefaultSpace if the user has no app spaces' do
        SecurityContext.set(user)
        api = LegacyApiBase.new(TestConfig.config_instance, logger, {}, {}, fake_req, nil, dependencies)
        expect do
          api.default_space
        end.to raise_error(CloudController::Errors::ApiError, /legacy api call requiring a default app space was called/)
      end

      context 'with app spaces' do
        let(:org) { Organization.make }
        let(:as1) { Space.make(organization: org) }
        let(:as2) { Space.make(organization: org) }
        let(:api) do
          SecurityContext.set(user)
          LegacyApiBase.new(TestConfig.config_instance, logger, {}, {}, fake_req, nil, dependencies)
        end

        before do
          user.add_organization(org)
          user.add_space(as1)
          user.add_space(as2)
        end

        it 'returns the first app space a user is in if default_space is not set' do
          expect(api.default_space).to eq(as1)
          user.remove_space(as1)
          expect(api.default_space).to eq(as2)
        end

        it 'returns the explicitly set default app space if one is set' do
          user.default_space = as2
          expect(api.default_space).to eq(as2)
        end
      end
    end
  end
end
