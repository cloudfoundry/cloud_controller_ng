require 'spec_helper'
require 'messages/validators/metadata_validator'

module VCAP::CloudController::Validators
  RSpec.describe 'MetadataValidator' do
    let(:class_with_metadata) do
      Class.new do
        include ActiveModel::Model
        validates_with MetadataValidator

        attr_accessor :metadata

        def labels
          HashUtils.dig(metadata, :labels)
        end
      end
    end

    subject(:message) do
      class_with_metadata.new(metadata: metadata)
    end

    let(:metadata) { { labels: labels } }
    let(:labels) { {} }

    context 'when labels are valid' do
      let(:labels) do
        {
            potato: 'mashed',
            p_otato: 'mashed',
            'p.otato': 'mashed',
            'p-otato': 'mashed',
            yams: nil
        }
      end

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when labels are not a hash' do
      let(:labels) { 'potato' }

      it 'is invalid' do
        expect(subject).not_to be_valid
        expect(subject.errors_on(:metadata)).to include("'labels' is not a hash")
      end
    end

    describe 'invalid keys' do
      context 'when the key contains one invalid character' do
        # for the 32nd-126th characters, excluding the ones inside of the %r()
        (32.chr..126.chr).to_a.reject { |c| %r([\w\-\.\_\/\s]).match(c) }.each do |c|
          it "is invalid for character '#{c}'" do
            metadata = {
                labels: {
                    'potato' + c => 'mashed',
                    c => 'fried'

                }
            }
            message = class_with_metadata.new(metadata: metadata)
            expect(message).not_to be_valid
            expect(message.errors_on(:metadata)).to include("label key 'potato#{c}' contains invalid characters")
            expect(message.errors_on(:metadata)).to include("label key '#{c}' contains invalid characters")
          end
        end
      end
    end

    context 'when the first or last letter of the key is not alphanumeric' do
      let(:labels) do
        {
            '-a' => 'value1',
            'a-' => 'value2',
            '-' => 'value3',
            '.a' => 'value5',
            '_a': 'value4',
        }
      end
      it 'is invalid' do
        expect(subject).not_to be_valid
        expect(subject.errors_on(:metadata)).to include("label key '-a' starts or ends with invalid characters")
        expect(subject.errors_on(:metadata)).to include("label key 'a-' starts or ends with invalid characters")
        expect(subject.errors_on(:metadata)).to include("label key '-' starts or ends with invalid characters")
        expect(subject.errors_on(:metadata)).to include("label key '.a' starts or ends with invalid characters")
        expect(subject.errors_on(:metadata)).to include("label key '_a' starts or ends with invalid characters")
      end
    end

    context 'when the label key is exactly 63 characters' do
      let(:labels) do
        {
            'a' * VCAP::CloudController::Validators::LabelValidatorHelper::MAX_LABEL_SIZE => 'value2',
        }
      end
      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when the label key is greater than 63 characters' do
      let(:labels) do
        {
            'b' * (VCAP::CloudController::Validators::LabelValidatorHelper::MAX_LABEL_SIZE + 1) => 'value3',
        }
      end
      it 'is invalid' do
        expect(subject).not_to be_valid
        expect(subject.errors_on(:metadata)).
          to include("label key '#{'b' * 8}...' is greater than #{VCAP::CloudController::Validators::LabelValidatorHelper::MAX_LABEL_SIZE} characters")
      end
    end

    context 'when the label key is an empty string' do
      let(:labels) do
        {
            '' => 'value3',
            'example.com/': 'empty'
        }
      end

      it 'is invalid' do
        expect(subject).not_to be_valid
        expect(subject.errors_on(:metadata)).to contain_exactly('label key cannot be empty string', 'label key cannot be empty string')
      end
    end

    describe 'label key prefixes' do
      context 'when the key has a valid prefix' do
        let(:key_with_long_domain) { (('a' * 61) + '.sub-part.' + ('b' * 61) + '.com/release').to_sym }
        let(:labels) do
          {
              'example.com/potato': 'mashed',
              key_with_long_domain => 'stable',
              'capi.ci.cf-app.com/dashboard': 'green',
          }
        end

        it 'is valid' do
          expect(subject).to be_valid
          expect(subject.labels).to include('example.com/potato': 'mashed')
          expect(subject.labels).to include(key_with_long_domain.to_sym => 'stable')
          expect(subject.labels).to include('capi.ci.cf-app.com/dashboard': 'green')
          expect(subject.labels.size).to equal(3)
        end
      end

      context 'when the key has more than one prefix' do
        let(:labels) do
          {
              'example.com/capi/tests': 'failing'
          }
        end

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).to contain_exactly("label key has more than one '/'")
        end
      end

      context 'when the prefix is not a valid domain' do
        let(:labels) do
          {
              '-a/key1' => 'value1',
              'a%a.com/key2' => 'value2',
              'a..com/key3' => 'value3',
              'onlycom/key4' => 'value5',
          }
        end

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).to include("label prefix '-a' must be in valid dns format")
          expect(subject.errors_on(:metadata)).to include("label prefix 'a%a.com' must be in valid dns format")
          expect(subject.errors_on(:metadata)).to include("label prefix 'a..com' must be in valid dns format")
          expect(subject.errors_on(:metadata)).to include("label prefix 'onlycom' must be in valid dns format")
        end
      end

      context 'when the prefix is too long' do
        let(:long_domain) do
          ['a', 'b', 'c', 'd', 'e'].map { |c| c * 61 }.join('.')
        end

        let(:labels) do
          {
              long_domain + '/key' => 'value1',
          }
        end

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).to contain_exactly("label prefix 'aaaaaaaa...' is greater than 253 characters")
        end
      end
    end

    describe 'invalid label values' do
      context 'when the values contains one invalid character' do
        (32.chr..126.chr).to_a.reject { |c| /[\w\-\.\_]/.match(c) }.each do |c|
          it "is invalid for character '#{c}'" do
            metadata = {
                labels: {
                    'potato' => 'mashed' + c,
                    'release' => c
                }
            }
            message = class_with_metadata.new(metadata: metadata)
            expect(message).not_to be_valid
            expect(message.errors_on(:metadata)).to include("label value 'mashed#{c}' contains invalid characters")
            expect(message.errors_on(:metadata)).to include("label value '#{c}' contains invalid characters")
          end
        end
      end

      context 'when the first or last letter of the value is not alphanumeric' do
        let(:labels) do
          {
              'key1' => '-a',
              'key2' => 'a-',
              'key3' => '-',
              'key4' => '.a',
              'key5' => '_a',
          }
        end
        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).to include("label value '-a' starts or ends with invalid characters")
          expect(subject.errors_on(:metadata)).to include("label value 'a-' starts or ends with invalid characters")
          expect(subject.errors_on(:metadata)).to include("label value '-' starts or ends with invalid characters")
          expect(subject.errors_on(:metadata)).to include("label value '.a' starts or ends with invalid characters")
          expect(subject.errors_on(:metadata)).to include("label value '_a' starts or ends with invalid characters")
        end
      end

      context 'when the label value is exactly 63 characters' do
        let(:labels) do
          {
              'key' => 'a' * VCAP::CloudController::Validators::LabelValidatorHelper::MAX_LABEL_SIZE,
          }
        end
        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when the label value is greater than 63 characters' do
        let(:labels) do
          {
              'key' => 'b' * (VCAP::CloudController::Validators::LabelValidatorHelper::MAX_LABEL_SIZE + 1),
          }
        end
        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).
            to include("label value '#{'b' * 8}...' is greater than #{VCAP::CloudController::Validators::LabelValidatorHelper::MAX_LABEL_SIZE} characters")
        end
      end
    end
  end
end
