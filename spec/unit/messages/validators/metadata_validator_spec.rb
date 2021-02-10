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

        def annotations
          HashUtils.dig(metadata, :annotations)
        end
      end
    end

    subject(:message) do
      class_with_metadata.new(metadata: metadata)
    end

    context 'validating metadata' do
      context 'when there is non-label and non-annotation metadata' do
        let(:metadata) do
          {
            other: 'stuff',
            extra: 'fields'
          }
        end

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).to contain_exactly("has unexpected field(s): 'other' 'extra'")
        end
      end

      context 'when metadata is not an object' do
        let(:metadata) { 'notahash' }

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).to contain_exactly('must be an object')
        end
      end
    end

    context 'validating message with labels' do
      let(:metadata) { { labels: labels } }
      let(:labels) { {} }

      context 'when labels are valid' do
        let(:labels) do
          {
              potato: 'mashed',
              p_otato: 'mashed',
              'p.otato': 'mashed',
              'p-otato': 'mashed',
              empty: '',
              yams: nil
          }
        end

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when labels are not an object' do
        let(:labels) { 'potato' }

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).to include("'labels' is not an object")
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
              expect(message.errors_on(:metadata)).to include("label key error: 'potato#{c}' contains invalid characters")
              expect(message.errors_on(:metadata)).to include("label key error: '#{c}' contains invalid characters")
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
              _a: 'value4',
          }
        end
        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).to include("label key error: '-a' starts or ends with invalid characters")
          expect(subject.errors_on(:metadata)).to include("label key error: 'a-' starts or ends with invalid characters")
          expect(subject.errors_on(:metadata)).to include("label key error: '-' starts or ends with invalid characters")
          expect(subject.errors_on(:metadata)).to include("label key error: '.a' starts or ends with invalid characters")
          expect(subject.errors_on(:metadata)).to include("label key error: '_a' starts or ends with invalid characters")
        end
      end

      context 'when the label key is exactly 63 characters' do
        let(:labels) do
          {
              'a' * MetadataValidatorHelper::MAX_METADATA_KEY_SIZE => 'value2',
          }
        end
        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when the label key is greater than 63 characters' do
        let(:labels) do
          {
              'b' * (MetadataValidatorHelper::MAX_METADATA_KEY_SIZE + 1) => 'value3',
          }
        end
        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).
            to include("label key error: '#{'b' * 8}...' is greater than #{MetadataValidatorHelper::MAX_METADATA_KEY_SIZE} characters")
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
          expect(subject.errors_on(:metadata)).to contain_exactly('label key error: key cannot be empty string', 'label key error: key cannot be empty string')
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
            expect(subject.errors_on(:metadata)).to contain_exactly("label key error: key has more than one '/'")
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
            expect(subject.errors_on(:metadata)).to include("label key error: prefix '-a' must be in valid dns format")
            expect(subject.errors_on(:metadata)).to include("label key error: prefix 'a%a.com' must be in valid dns format")
            expect(subject.errors_on(:metadata)).to include("label key error: prefix 'a..com' must be in valid dns format")
            expect(subject.errors_on(:metadata)).to include("label key error: prefix 'onlycom' must be in valid dns format")
          end
        end

        context 'when the prefix includes some variation of cloudfoundry.org, a reserved domain' do
          let(:labels) do
            {
                'cloudfoundry.org/key' => 'value',
                'CloudFoundry.org/key' => 'value',
            }
          end

          it 'is invalid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:metadata)).to include('label key error: prefix \'cloudfoundry.org\' is reserved')
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
            expect(subject.errors_on(:metadata)).to contain_exactly("label key error: prefix 'aaaaaaaa...' is greater than 253 characters")
          end
        end
      end

      describe 'invalid labels value error' do
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
              expect(message.errors_on(:metadata)).to include("label value error: 'mashed#{c}' contains invalid characters")
              expect(message.errors_on(:metadata)).to include("label value error: '#{c}' contains invalid characters")
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
            expect(subject.errors_on(:metadata)).to include("label value error: '-a' starts or ends with invalid characters")
            expect(subject.errors_on(:metadata)).to include("label value error: 'a-' starts or ends with invalid characters")
            expect(subject.errors_on(:metadata)).to include("label value error: '-' starts or ends with invalid characters")
            expect(subject.errors_on(:metadata)).to include("label value error: '.a' starts or ends with invalid characters")
            expect(subject.errors_on(:metadata)).to include("label value error: '_a' starts or ends with invalid characters")
          end
        end

        context 'when the label value is exactly 63 characters' do
          let(:labels) do
            {
                'key' => 'a' * MetadataValidatorHelper::MAX_METADATA_KEY_SIZE,
            }
          end
          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when the label value is greater than 63 characters' do
          let(:labels) do
            {
                'key' => 'b' * (MetadataValidatorHelper::MAX_METADATA_KEY_SIZE + 1),
            }
          end
          it 'is labeldinvalivalue error: ' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:metadata)).
              to include("label value error: '#{'b' * 8}...' is greater than #{MetadataValidatorHelper::MAX_METADATA_KEY_SIZE} characters")
          end
        end
      end
    end

    context 'when message has annotations' do
      let(:metadata) { { annotations: annotations } }
      let(:annotations) { {} }

      context 'validating message with annotations' do
        let(:annotations) do
          {
            contacts: 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)',
            "Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)": 'contacts',
            ('a' * MetadataValidatorHelper::MAX_METADATA_KEY_SIZE) => ('b' * MetadataValidator::MAX_ANNOTATION_VALUE_SIZE)
          }
        end

        it 'is valid' do
          expect(subject).not_to be_valid
        end
      end

      context 'when annotations are not an object' do
        let(:annotations) { 'potato' }

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).to include("'annotations' is not an object")
        end
      end

      context 'when the annotation key is invalid' do
        let(:annotations) do
          {
            'b' * (MetadataValidatorHelper::MAX_METADATA_KEY_SIZE + 1) => 'value3',
          }
        end
        it 'its invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).
            to include("annotation key error: '#{'b' * 8}...' is greater than #{MetadataValidatorHelper::MAX_METADATA_KEY_SIZE} characters")
        end

        context 'and it is going to be deleted' do
          let(:annotations) do
            {
              'b' * (MetadataValidatorHelper::MAX_METADATA_KEY_SIZE + 1) => '',
            }
          end

          it 'does not run validations' do
            expect(subject).to be_valid
          end
        end
      end

      context 'when the annotations key is an empty string' do
        let(:annotations) do
          {
            '' => 'value3'
          }
        end

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).to include('annotation key error: key cannot be empty string')
        end
      end

      context 'when the annotation value is greater than 5000 characters' do
        let(:annotations) do
          {
            'key' => ('a' * (MetadataValidator::MAX_ANNOTATION_VALUE_SIZE + 1)),
          }
        end
        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors_on(:metadata)).
            to include("annotation value error: '#{'a' * 8}...' is greater than #{MetadataValidator::MAX_ANNOTATION_VALUE_SIZE} characters")
        end
      end
    end
  end
end
