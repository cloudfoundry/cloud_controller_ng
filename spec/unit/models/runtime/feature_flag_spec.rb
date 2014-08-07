require 'spec_helper'

module VCAP::CloudController
  describe FeatureFlag, type: :model do
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
            expect(subject).to_not be_valid
          end
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :enabled }
      it { is_expected.to import_attributes :name, :enabled }
    end

    describe '.enabled?' do
      let(:key) { 'user_org_creation' }
      let(:default_value) { FeatureFlag::DEFAULT_FLAGS[key.to_sym] }

      context 'when the feature flag is overridden' do
        before do
          FeatureFlag.create(name: key, enabled: !default_value)
        end

        it 'should return the override value' do
          expect(FeatureFlag.enabled?(key)).to eq(!default_value)
        end
      end

      context 'when the feature flag is not overridden' do
        it 'should return the default value' do
          expect(FeatureFlag.enabled?(key)).to eq(default_value)
        end
      end

      context 'when feature flag does not exist' do
        it 'blows up somehow' do
          expect {
            FeatureFlag.enabled?('bogus_feature_flag')
          }.to raise_error(FeatureFlag::UndefinedFeatureFlagError, /bogus_feature_flag/)
        end
      end
    end

    describe '.raise_unless_enabled!' do
      let(:message) { 'some message' }

      context 'when the flag is enabled' do
        before do
          feature_flag.enabled = true
          feature_flag.save
        end

        it 'does not raise an error' do
          expect { FeatureFlag.raise_unless_enabled!(feature_flag.name, message) }.to_not raise_error
        end
      end

      context 'when the flag is disabled' do
        before do
          feature_flag.enabled = false
          feature_flag.save
        end

        it 'raises FeatureDisabled' do
          expect { FeatureFlag.raise_unless_enabled!(feature_flag.name, message) }.to raise_error(VCAP::Errors::ApiError) do |error|
            expect(error.name).to eq('FeatureDisabled')
            expect(error.message).to eq(message)
          end
        end

        context 'and there is a custom operator defined error message' do
          before do
            TestConfig.override(feature_disabled_message: 'my custom error message')
          end

          it 'raises FeatureDisabled with the custom error message' do
            expect { FeatureFlag.raise_unless_enabled!(feature_flag.name, message) }.to raise_error(VCAP::Errors::ApiError) do |error|
              expect(error.name).to eq('FeatureDisabled')
              expect(error.message).to eq("#{message}: my custom error message")
            end
          end
        end
      end
    end
  end
end
