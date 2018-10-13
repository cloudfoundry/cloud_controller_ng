require 'spec_helper'
require 'messages/app_update_message'

module VCAP::CloudController
  RSpec.describe AppUpdateMessage do
    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'foo' } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when name is not a string' do
        let(:params) { { name: 32.77 } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:name)).to include('must be a string')
        end
      end

      context 'when we have more than one error' do
        let(:params) { { name: 3.5, unexpected: 'foo' } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(2)
          expect(message.errors.full_messages).to match_array([
            'Name must be a string',
            "Unknown field(s): 'unexpected'"
          ])
        end
      end
      describe 'lifecycle' do
        context 'when lifecycle is provided' do
          let(:params) do
            {
              name: 'some_name',
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpacks: ['java'],
                  stack: 'cflinuxfs2'
                }
              }
            }
          end

          it 'is valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to be_valid
          end
        end

        context 'when lifecycle data is provided' do
          let(:params) do
            {
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpacks: [123],
                  stack: 324
                }
              }
            }
          end

          it 'must provide a valid buildpack value' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle)).to include('Buildpacks can only contain strings')
          end

          it 'must provide a valid stack name' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle)).to include('Stack must be a string')
          end
        end

        context 'when data is not provided' do
          let(:params) do
            { lifecycle: { type: 'buildpack' } }
          end

          it 'is not valid' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle_data)).to include('must be a hash')
          end
        end

        context 'when lifecycle is not provided' do
          let(:params) do
            {
              name: 'some_name',
            }
          end

          it 'does not supply defaults' do
            message = AppUpdateMessage.new(params)
            expect(message).to be_valid
            expect(message.lifecycle).to eq(nil)
          end
        end

        context 'when lifecycle type is not provided' do
          let(:params) do
            {
              lifecycle: {
                data: {}
              }
            }
          end

          it 'is not valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to_not be_valid

            expect(message.errors_on(:lifecycle_type)).to include('must be a string')
          end
        end

        context 'when lifecycle data is not a hash' do
          let(:params) do
            {
              lifecycle: {
                type: 'buildpack',
                data: 'potato'
              }
            }
          end

          it 'is not valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to_not be_valid

            expect(message.errors_on(:lifecycle_data)).to include('must be a hash')
          end
        end
      end
      describe 'metadata' do
        context 'when labels are valid' do
          let(:params) do
            {
              "metadata": {
                "labels": {
                  "potato": 'mashed',
                  "p_otato": 'mashed',
                  "p.otato": 'mashed',
                  "p-otato": 'mashed',
                }
              }
            }
          end

          it 'is valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to be_valid
          end

          it 'builds a message with access to the labels' do
            message = AppUpdateMessage.new(params)
            expect(message.labels).to include("potato": 'mashed')
            expect(message.labels).to include("p_otato": 'mashed')
            expect(message.labels).to include("p.otato": 'mashed')
            expect(message.labels).to include("p-otato": 'mashed')
            expect(message.labels.size).to equal(4)
          end
        end

        context 'when labels are not a hash' do
          let(:params) do
            {
              "metadata": {
                "labels": 'potato',
              }
            }
          end
          it 'is invalid' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:metadata)).to include("'labels' is not a hash")
          end
        end

        describe 'invalid keys' do
          context 'when the key contains one invalid character' do
            (32.chr..126.chr).to_a.reject { |c| %r([\w\-\.\_\/]).match(c) }.each do |c|
              it "is invalid for character '#{c}'" do
                params = {
                  "metadata": {
                    "labels": {
                      'potato' + c => 'mashed',
                      c => 'fried'
                    }
                  }
                }
                message = AppUpdateMessage.new(params)
                expect(message).not_to be_valid
                expect(message.errors_on(:metadata)).to include("label key 'potato#{c}' contains invalid characters")
                expect(message.errors_on(:metadata)).to include("label key '#{c}' contains invalid characters")
              end
            end
          end

          context 'when the first or last letter of the key is not alphanumeric' do
            let(:params) do
              {
                "metadata": {
                  "labels": {
                    '-a' => 'value1',
                    'a-' => 'value2',
                    '-' => 'value3',
                    '.a' => 'value5',
                    '_a': 'value4',
                  }
                }
              }
            end
            it 'is invalid' do
              message = AppUpdateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors_on(:metadata)).to include("label key '-a' starts or ends with invalid characters")
              expect(message.errors_on(:metadata)).to include("label key 'a-' starts or ends with invalid characters")
              expect(message.errors_on(:metadata)).to include("label key '-' starts or ends with invalid characters")
              expect(message.errors_on(:metadata)).to include("label key '.a' starts or ends with invalid characters")
              expect(message.errors_on(:metadata)).to include("label key '_a' starts or ends with invalid characters")
            end
          end

          context 'when the label key is exactly 63 characters' do
            let(:params) do
              {
                "metadata": {
                  "labels": {
                    'a' * AppUpdateMessage::MAX_LABEL_SIZE => 'value2',
                  }
                }
              }
            end
            it 'is valid' do
              message = AppUpdateMessage.new(params)
              expect(message).to be_valid
            end
          end

          context 'when the label key is greater than 63 characters' do
            let(:params) do
              {
                "metadata": {
                  "labels": {
                    'b' * (AppUpdateMessage::MAX_LABEL_SIZE + 1) => 'value3',
                  }
                }
              }
            end
            it 'is invalid' do
              message = AppUpdateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors_on(:metadata)).to include("label key '#{'b' * 8}...' is greater than #{AppUpdateMessage::MAX_LABEL_SIZE} characters")
            end
          end

          context 'when the label key is an empty string' do
            let(:params) do
              {
                "metadata": {
                  "labels": {
                    '' => 'value3',
                    'example.com/': 'empty'
                  }
                }
              }
            end
            it 'is invalid' do
              message = AppUpdateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors_on(:metadata)).to contain_exactly('label key cannot be empty string', 'label key cannot be empty string')
            end
          end
        end

        describe 'label key namespaces' do
          context 'when the key has a valid prefix' do
            let(:key_with_long_domain) { (('a' * 61) + '.sub-part.' + ('b' * 61) + '.com/release').to_sym }
            let(:params) do
              {
                "metadata": {
                  "labels": {
                    'example.com/potato': 'mashed',
                    key_with_long_domain => 'stable',
                    'capi.ci.cf-app.com/dashboard' => 'green',
                  }
                }
              }
            end

            it 'is valid' do
              message = AppUpdateMessage.new(params)
              puts message.errors_on(:metadata)
              expect(message).to be_valid
              expect(message.labels).to include('example.com/potato': 'mashed')
              expect(message.labels).to include(key_with_long_domain.to_sym => 'stable')
              expect(message.labels).to include('capi.ci.cf-app.com/dashboard': 'green')
              expect(message.labels.size).to equal(3)
            end
          end

          context 'when the key has more than one prefix' do
            let(:params) do
              {
                "metadata": {
                  "labels": {
                    'example.com/capi/tests': 'failing'
                  }
                }
              }
            end
            it 'is invalid' do
              message = AppUpdateMessage.new(params)
              expect(message).not_to be_valid
              expect(message.errors_on(:metadata)).to contain_exactly("label key has more than one '/'")
            end
          end
        end

        context 'when the namespace is not a valid domain' do
          let(:params) do
            {
              "metadata": {
                "labels": {
                  '-a/key1' => 'value1',
                  'a%a.com/key2' => 'value2',
                  'a..com/key3' => 'value3',
                  'onlycom/key4' => 'value5',
                }
              }
            }
          end
          it 'is invalid' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:metadata)).to include("label namespace '-a' must be in valid dns format")
            expect(message.errors_on(:metadata)).to include("label namespace 'a%a.com' must be in valid dns format")
            expect(message.errors_on(:metadata)).to include("label namespace 'a..com' must be in valid dns format")
            expect(message.errors_on(:metadata)).to include("label namespace 'onlycom' must be in valid dns format")
          end
        end

        context 'when the namespace is too long' do
          let(:long_domain) do
            ['a', 'b', 'c', 'd', 'e'].map { |c| c * 61 }.join('.')
          end

          let(:params) do
            {
              "metadata": {
                "labels": {
                  long_domain + '/key' => 'value1',
                }
              }
            }
          end

          it 'is invalid' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:metadata)).to contain_exactly("label namespace 'aaaaaaaa...' is greater than 253 characters")
          end
        end

        describe 'invalid label values' do
          context 'when the values contains one invalid character' do
            (32.chr..126.chr).to_a.reject { |c| /[\w\-\.\_]/.match(c) }.each do |c|
              it "is invalid for character '#{c}'" do
                params = {
                  "metadata": {
                    "labels": {
                      'potato' => 'mashed' + c,
                      'release' => c
                    }
                  }
                }
                message = AppUpdateMessage.new(params)
                expect(message).not_to be_valid
                expect(message.errors_on(:metadata)).to include("label value 'mashed#{c}' contains invalid characters")
                expect(message.errors_on(:metadata)).to include("label value '#{c}' contains invalid characters")
              end
            end
          end
        end

        context 'when the first or last letter of the value is not alphanumeric' do
          let(:params) do
            {
              "metadata": {
                "labels": {
                  'key1' => '-a',
                  'key2' => 'a-',
                  'key3' => '-',
                  'key4' => '.a',
                  'key5' => '_a',
                }
              }
            }
          end
          it 'is invalid' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:metadata)).to include("label value '-a' starts or ends with invalid characters")
            expect(message.errors_on(:metadata)).to include("label value 'a-' starts or ends with invalid characters")
            expect(message.errors_on(:metadata)).to include("label value '-' starts or ends with invalid characters")
            expect(message.errors_on(:metadata)).to include("label value '.a' starts or ends with invalid characters")
            expect(message.errors_on(:metadata)).to include("label value '_a' starts or ends with invalid characters")
          end
        end

        context 'when the label value is exactly 63 characters' do
          let(:params) do
            {
              "metadata": {
                "labels": {
                  'key' => 'a' * AppUpdateMessage::MAX_LABEL_SIZE,
                }
              }
            }
          end
          it 'is valid' do
            message = AppUpdateMessage.new(params)
            expect(message).to be_valid
          end
        end

        context 'when the label value is greater than 63 characters' do
          let(:params) do
            {
              "metadata": {
                "labels": {
                  'key' => 'b' * (AppUpdateMessage::MAX_LABEL_SIZE + 1),
                }
              }
            }
          end
          it 'is invalid' do
            message = AppUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:metadata)).to include("label value '#{'b' * 8}...' is greater than #{AppUpdateMessage::MAX_LABEL_SIZE} characters")
          end
        end
      end
    end
  end
end
