# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  describe FeatureFlag, type: :model do
    let(:valid_flags) { [:user_org_creation, :private_domain_creation, :app_bits_upload, :app_scaling, :route_creation, :service_instance_creation] }
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

      describe 'error message' do
        subject(:feature_flag) { FeatureFlag.make }

        it 'shoud allow standard ascii characters' do
          feature_flag.error_message = "A -_- word 2!?()\'\'&+."
          expect {
            feature_flag.save
          }.to_not raise_error
        end

        it 'should allow backslash characters' do
          feature_flag.error_message = 'a\\word'
          expect {
            feature_flag.save
          }.to_not raise_error
        end

        it 'should allow unicode characters' do
          feature_flag.error_message = '防御力¡'
          expect {
            feature_flag.save
          }.to_not raise_error
        end

        it 'should not allow newline characters' do
          feature_flag.error_message = "one\ntwo"
          expect {
            feature_flag.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should not allow escape characters' do
          feature_flag.error_message = "a\e word"
          expect {
            feature_flag.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should allow an empty error_message' do
          feature_flag.error_message = nil
          expect {
            feature_flag.save
          }.to_not raise_error
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :enabled, :error_message }
      it { is_expected.to import_attributes :name, :enabled, :error_message }
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
      context 'when the flag is enabled' do
        before do
          feature_flag.enabled = true
          feature_flag.save
        end

        it 'does not raise an error' do
          expect { FeatureFlag.raise_unless_enabled!(feature_flag.name) }.to_not raise_error
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
            expect { FeatureFlag.raise_unless_enabled!(feature_flag.name) }.to raise_error(VCAP::Errors::ApiError) do |error|
              expect(error.name).to eq('FeatureDisabled')
              expect(error.message).to eq("Feature Disabled: #{feature_flag.name}")
            end
          end
        end

        context 'and there is a custom operator defined error message' do
          let(:feature_flag) { FeatureFlag.make(error_message: 'foobar') }

          it 'raises FeatureDisabled with the custom error message' do
            expect { FeatureFlag.raise_unless_enabled!(feature_flag.name) }.to raise_error(VCAP::Errors::ApiError) do |error|
              expect(error.name).to eq('FeatureDisabled')
              expect(error.message).to eq("Feature Disabled: #{feature_flag.error_message}")
            end
          end
        end
      end

      context 'when the flag does not exist' do
        it 'blows up somehow' do
          expect {
            FeatureFlag.raise_unless_enabled!('bogus_feature_flag')
          }.to raise_error(FeatureFlag::UndefinedFeatureFlagError, /bogus_feature_flag/)
        end
      end
    end

    describe 'valid feature flags' do
      it 'includes the expected flags' do
        expect(FeatureFlag::DEFAULT_FLAGS.keys).to eq(valid_flags)
      end
    end
  end
end
