require 'spec_helper'

module VCAP::CloudController
  RSpec.describe FeatureFlag, type: :model do
    let(:feature_flag) { FeatureFlag.make }

    it { is_expected.to have_timestamp_columns }

    describe 'Validations' do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_presence :enabled }

      it 'validates name is unique' do
        existing_flag       = FeatureFlag.make
        duplicate_flag      = FeatureFlag.new
        duplicate_flag.name = existing_flag.name
        expect { duplicate_flag.save }.to raise_error(Sequel::ValidationFailed, /name unique/)
      end

      context 'name validation' do
        context 'with a valid name' do
          it 'allows creation of a feature flag that has a corresponding default' do
            subject.name    = 'user_org_creation'
            subject.enabled = false
            expect(subject).to be_valid
          end
        end

        context 'with an invalid name' do
          it 'does not allow creation of a feature flag that has no corresponding default' do
            subject.name    = 'not-a-real-value'
            subject.enabled = false
            expect(subject).not_to be_valid
          end
        end
      end

      describe 'error message' do
        subject(:feature_flag) { FeatureFlag.make }

        it 'shoud allow standard ascii characters' do
          feature_flag.error_message = "A -_- word 2!?()''&+."
          expect do
            feature_flag.save
          end.not_to raise_error
        end

        it 'allows backslash characters' do
          feature_flag.error_message = 'a\\word'
          expect do
            feature_flag.save
          end.not_to raise_error
        end

        it 'allows unicode characters' do
          feature_flag.error_message = '防御力¡'
          expect do
            feature_flag.save
          end.not_to raise_error
        end

        it 'does not allow newline characters' do
          feature_flag.error_message = "one\ntwo"
          expect do
            feature_flag.save
          end.to raise_error(Sequel::ValidationFailed)
        end

        it 'does not allow escape characters' do
          feature_flag.error_message = "a\e word"
          expect do
            feature_flag.save
          end.to raise_error(Sequel::ValidationFailed)
        end

        it 'allows an empty error_message' do
          feature_flag.error_message = nil
          expect do
            feature_flag.save
          end.not_to raise_error
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :enabled, :error_message }
      it { is_expected.to import_attributes :name, :enabled, :error_message }
    end

    describe '.enabled?' do
      let(:key) { :user_org_creation }
      let(:default_value) { FeatureFlag::DEFAULT_FLAGS[key] }

      context 'when the feature flag is overridden' do
        before do
          FeatureFlag.create(name: key, enabled: !default_value)
        end

        it 'returns the override value' do
          expect(FeatureFlag.enabled?(key)).to eq(!default_value)
          expect(FeatureFlag.disabled?(key)).to eq(default_value)
        end
      end

      context 'when the feature flag is not overridden' do
        it 'returns the default value' do
          expect(FeatureFlag.enabled?(key)).to eq(default_value)
          expect(FeatureFlag.disabled?(key)).not_to eq(default_value)
        end
      end

      context 'when feature flag does not exist' do
        it 'blows up somehow' do
          expect do
            FeatureFlag.enabled?(:bogus_feature_flag)
          end.to raise_error(FeatureFlag::UndefinedFeatureFlagError, /bogus_feature_flag/)
          expect do
            FeatureFlag.disabled?(:bogus_feature_flag)
          end.to raise_error(FeatureFlag::UndefinedFeatureFlagError, /bogus_feature_flag/)
        end
      end

      context 'when logged in as an admin' do
        before do
          allow(VCAP::CloudController::SecurityContext).to receive(:admin?).and_return(true)
          stub_const('VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS', { normal: false, blahrgha: false })
          stub_const('VCAP::CloudController::FeatureFlag::ADMIN_SKIPPABLE', [:blahrgha])
        end

        context 'when flag is admin enabled' do
          it 'is always enabled' do
            FeatureFlag.create(name: 'blahrgha', enabled: false)

            expect(FeatureFlag.enabled?(:blahrgha)).to be(true)
          end
        end

        context 'when flag is not admin enabled' do
          it 'is false if the flag is disabled' do
            FeatureFlag.create(name: 'normal', enabled: false)

            expect(FeatureFlag.enabled?(:normal)).to be(false)
          end
        end
      end

      context 'when logged in as an admin read only' do
        before do
          allow(VCAP::CloudController::SecurityContext).to receive(:admin_read_only?).and_return(true)
          stub_const('VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS', { normal: false, potato: false, tomato: false })
          stub_const('VCAP::CloudController::FeatureFlag::ADMIN_READ_ONLY_SKIPPABLE', [:potato])
          stub_const('VCAP::CloudController::FeatureFlag::ADMIN__SKIPPABLE', [:tomato])
        end

        context 'when flag is admin read only enabled' do
          it 'is always enabled' do
            FeatureFlag.create(name: 'potato', enabled: false)

            expect(FeatureFlag.enabled?(:potato)).to be(true)
          end
        end

        context 'when flag is not admin read only enabled' do
          it 'is false if the flag is disabled' do
            FeatureFlag.create(name: 'normal', enabled: false)

            expect(FeatureFlag.enabled?(:normal)).to be(false)
          end
        end
      end
    end

    describe '.raise_unless_enabled!' do
      before do
        allow(FeatureFlag).to receive(:find).once.and_call_original
      end

      context 'when the flag is enabled' do
        before do
          feature_flag.enabled = true
          feature_flag.save
        end

        it 'does not raise an error' do
          expect { FeatureFlag.raise_unless_enabled!(feature_flag.name) }.not_to raise_error
        end
      end

      context 'when the flag is disabled' do
        before do
          feature_flag.enabled = false
          feature_flag.save
        end

        context 'and there is no custom error message defined' do
          before do
            feature_flag.update(error_message: nil)
          end

          it 'raises FeatureDisabled with feature flag name' do
            expect { FeatureFlag.raise_unless_enabled!(feature_flag.name) }.to raise_error(CloudController::Errors::ApiError) do |error|
              expect(error.name).to eq('FeatureDisabled')
              expect(error.message).to eq("Feature Disabled: #{feature_flag.name}")
            end
          end
        end

        context 'and there is a custom operator defined error message' do
          let(:feature_flag) { FeatureFlag.make(error_message: 'foobar') }

          it 'raises FeatureDisabled with the custom error message' do
            expect { FeatureFlag.raise_unless_enabled!(feature_flag.name) }.to raise_error(CloudController::Errors::ApiError) do |error|
              expect(error.name).to eq('FeatureDisabled')
              expect(error.message).to eq("Feature Disabled: #{feature_flag.error_message}")
            end
          end
        end
      end

      context 'when the flag does not exist' do
        it 'blows up somehow' do
          expect do
            FeatureFlag.raise_unless_enabled!(:bogus_feature_flag)
          end.to raise_error(FeatureFlag::UndefinedFeatureFlagError, /bogus_feature_flag/)
        end
      end
    end

    describe 'default flag override in config' do
      let(:key) { :diego_docker }
      let(:default_value) { FeatureFlag::DEFAULT_FLAGS[key] }

      context 'when there was no previously set conflicting value' do
        let(:config_value) { !default_value }

        before do
          FeatureFlag.override_default_flags({ key => config_value })
        end

        context 'and the value is not changed by admin' do
          it 'returns the config-set value' do
            expect(FeatureFlag.enabled?(key)).to be config_value
          end
        end

        context 'and the value is changed by admin' do
          let(:admin_value) { !config_value }
          let(:admin_override) do
            flag = FeatureFlag.find(name: key.to_s)
            flag.enabled = admin_value
            flag.save
          end

          before do
            admin_override
          end

          it 'returns the admin-set value' do
            expect(FeatureFlag.enabled?(key)).to be admin_value
          end
        end
      end

      context 'when there was previously set conflicting value' do
        let(:admin_value) { !default_value }

        before do
          FeatureFlag.make(name: key.to_s, enabled: admin_value)
        end

        it 'overwrites the existing admin-set value' do
          expect(FeatureFlag.enabled?(key)).to be admin_value
          FeatureFlag.override_default_flags({ key => !admin_value })
          expect(FeatureFlag.enabled?(key)).to be !admin_value
        end
      end
    end

    describe '.override_default_flags' do
      context 'with invalid flags' do
        it 'raises an error for the one and only invalid name' do
          feature_flag_overrides = { an_invalid_name: true }
          expect do
            FeatureFlag.override_default_flags(feature_flag_overrides)
          end.to raise_error('Invalid feature flag name(s): [:an_invalid_name]')
        end

        it 'raises an error for a mix of valid and invalid names' do
          feature_flag_overrides = { diego_docker: true, an_invalid_name: true }
          expect do
            FeatureFlag.override_default_flags(feature_flag_overrides)
          end.to raise_error('Invalid feature flag name(s): [:an_invalid_name]')
        end

        it 'raises an error for all invalid names' do
          feature_flag_overrides = { invalid_name1: true, invalid_name2: false }
          expect do
            FeatureFlag.override_default_flags(feature_flag_overrides)
          end.to raise_error('Invalid feature flag name(s): [:invalid_name1, :invalid_name2]')
        end

        it 'raises an error for invalid values' do
          feature_flag_overrides = { diego_docker: 'an invalid value', user_org_creation: false }
          expect do
            FeatureFlag.override_default_flags(feature_flag_overrides)
          end.to raise_error('Invalid feature flag value(s): {:diego_docker=>"an invalid value"}')
        end
      end

      context 'with valid flags' do
        let(:default_diego_docker_value) { FeatureFlag::DEFAULT_FLAGS[:diego_docker] }
        let(:default_user_org_creation_value) { FeatureFlag::DEFAULT_FLAGS[:user_org_creation] }

        before do
          expect do
            FeatureFlag.override_default_flags({ diego_docker: !default_diego_docker_value, user_org_creation: !default_user_org_creation_value })
          end.not_to raise_error
        end

        it 'updates values' do
          expect(FeatureFlag.enabled?(:diego_docker)).to be !default_diego_docker_value
          expect(FeatureFlag.enabled?(:user_org_creation)).to be !default_user_org_creation_value
        end
      end

      context 'with empty flags' do
        it 'no effect' do
          FeatureFlag.override_default_flags({})
          FeatureFlag::DEFAULT_FLAGS.each do |key, value|
            expect(FeatureFlag.enabled?(key)).to eq value
          end
        end
      end
    end
  end
end
