require 'spec_helper'
require 'messages/apps_list_message'

module VCAP::CloudController
  RSpec.describe AppsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'names' => 'name1,name2',
          'guids' => 'guid1,guid2',
          'organization_guids' => 'orgguid',
          'space_guids' => 'spaceguid',
          'page' => 1,
          'per_page' => 5,
          'order_by' => 'created_at',
          'include' => 'space',
          'label_selector' => 'foo in (stuff,things)',
        }
      end

      it 'returns the correct AppsListMessage' do
        message = AppsListMessage.from_params(params)

        expect(message).to be_a(AppsListMessage)
        expect(message.names).to eq(['name1', 'name2'])
        expect(message.guids).to eq(['guid1', 'guid2'])
        expect(message.organization_guids).to eq(['orgguid'])
        expect(message.space_guids).to eq(['spaceguid'])
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
        expect(message.include).to eq('space')
        expect(message.label_selector).to eq('foo in (stuff,things)')
        expect(message.requirements.first.key).to eq('foo')
        expect(message.requirements.first.operator).to eq(:in)
        expect(message.requirements.first.values).to contain_exactly('stuff', 'things')
      end

      it 'converts requested keys to symbols' do
        message = AppsListMessage.from_params(params)

        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:guids)).to be_truthy
        expect(message.requested?(:organization_guids)).to be_truthy
        expect(message.requested?(:space_guids)).to be_truthy
        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
        expect(message.requested?(:include)).to be_truthy
        expect(message.requested?(:label_selector)).to be_truthy
      end

      context 'validations' do
        context 'label_selector' do
          it 'validates that label_selector is not empty' do
            message = AppsListMessage.from_params('label_selector' => '')

            expect(message).to be_invalid
            expect(message.errors[:base].length).to eq 1
            expect(message.errors[:base].first).to match /Missing label_selector value/
          end

          it 'validates that no label_selector query is blank' do
            message = AppsListMessage.from_params('label_selector' => 'foo=bar, ')

            expect(message).to be_invalid
            expect(message.errors[:base].length).to eq 1
            expect(message.errors[:base].first).to match /Invalid label_selector value/
          end

          context 'invalid selector fields' do
            context 'invalid keys' do
              it 'marks as invalid keys that exceed the max length' do
                value = 'la' * 100
                message = AppsListMessage.from_params('label_selector' => "#{value} in (bar,baz)")

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /is greater than 63 characters/
              end

              it 'marks as invalid keys that start with non-alpha characters' do
                message = AppsListMessage.from_params('label_selector' => '-foo in (bar,baz)')

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /starts or ends with invalid characters/
              end

              it 'marks as invalid keys that contain forbidden characters' do
                message = AppsListMessage.from_params('label_selector' => 'f~oo in (bar,baz)')

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /contains invalid characters/
              end

              it 'marks as invalid keys that contain forbidden characters' do
                message = AppsListMessage.from_params('label_selector' => 'f~oo in (bar,baz)')

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /contains invalid characters/
              end

              it 'marks as invalid keys that contain multiple "/"s' do
                message = AppsListMessage.from_params('label_selector' => 'example.com/foo/bar in (bar,baz)')

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /label key has more than one/
              end

              it 'marks as invalid keys with non-dns prefixes' do
                message = AppsListMessage.from_params('label_selector' => 'example...com/bar in (bar,baz)')

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /must be in valid dns format/
              end

              it 'rejects reserved domains' do
                message = AppsListMessage.from_params('label_selector' => 'cloudfoundry.org/bar in (bar,baz)')

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /is a reserved domain/
              end

              it 'marks as invalid keys that with prefixes that exceed the max length' do
                prefix = 'la.' * 100
                message = AppsListMessage.from_params('label_selector' => "#{prefix}com/bar in (bar,baz)")

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /is greater than 253 characters/
              end

              it 'marks as invalid keys with prefixes but no name' do
                message = AppsListMessage.from_params('label_selector' => 'example.com/ in (bar,baz)')

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /label key cannot be empty string/
              end
            end

            context 'invalid operators' do
              it 'validates incorrect "in" operations' do
                message = AppsListMessage.from_params('label_selector' => 'foo inn (bar,baz)')

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /Invalid label_selector value/
              end

              it 'validates incorrect "notin" operations' do
                message = AppsListMessage.from_params('label_selector' => 'foo notinn (bar,baz)')

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /Invalid label_selector value/
              end

              it 'validates incorrect set operations' do
                message = AppsListMessage.from_params('label_selector' => 'foo == (bar,baz)')

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /Invalid label_selector value/
              end
            end

            context 'invalid values' do
              it 'marks as invalid values that exceed the max length' do
                value = 'la' * 100
                message = AppsListMessage.from_params('label_selector' => "foo in (bar,#{value})")

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /is greater than 63 characters/
              end

              it 'marks as invalid values that start with non-alpha characters' do
                message = AppsListMessage.from_params('label_selector' => 'foo in (bar,-baz)')

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /starts or ends with invalid characters/
              end

              it 'marks as invalid values that contain forbidden characters' do
                message = AppsListMessage.from_params('label_selector' => 'foo in (bar,b~az )')

                expect(message).to be_invalid
                expect(message.errors[:base].first).to match /contains invalid characters/
              end
            end
          end

          context 'set operations' do
            it 'validates correct in operation' do
              message = AppsListMessage.from_params('label_selector' => 'example.com/foo in (bar,baz)')

              expect(message).to be_valid
            end

            it 'validates correct notin operation' do
              message = AppsListMessage.from_params('label_selector' => 'foo notin (bar,baz)')

              expect(message).to be_valid
            end
          end

          context 'equality operation' do
            it 'validates correct = operation' do
              message = AppsListMessage.from_params('label_selector' => 'example.com/foo=bar')

              expect(message).to be_valid
            end

            it 'validates correct == operation' do
              message = AppsListMessage.from_params('label_selector' => 'example.com/foo==bar')

              expect(message).to be_valid
            end

            it 'validates correct != operation' do
              message = AppsListMessage.from_params('label_selector' => 'example.com/foo!=bar')

              expect(message).to be_valid
            end
          end

          context 'existence operations' do
            it 'validates correct existence operation' do
              message = AppsListMessage.from_params('label_selector' => 'example.com/foo')

              expect(message).to be_valid
            end

            it 'validates correct non-existence operation' do
              message = AppsListMessage.from_params('label_selector' => '!example.com/foo')

              expect(message).to be_valid
            end
          end
        end
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          names: ['name1', 'name2'],
          guids: ['guid1', 'guid2'],
          organization_guids: ['orgguid1', 'orgguid2'],
          space_guids: ['spaceguid1', 'spaceguid2'],
          page: 1,
          per_page: 5,
          order_by: 'created_at',
          include: 'space',
          label_selector: 'foo in (stuff,things)'
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:names, :guids, :organization_guids, :space_guids, :include, :label_selector]
        expect(AppsListMessage.new(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          AppsListMessage.new({
                                names: [],
                                guids: [],
                                organization_guids: [],
                                space_guids: [],
                                page: 1,
                                per_page: 5,
                                order_by: 'created_at',
                                include: 'space',
                                label_selector: 'foo in (stuff,things)'
                              })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = AppsListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = AppsListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end

      it 'does not accept include that is not space' do
        message = AppsListMessage.new({ include: 'space' })
        expect(message).to be_valid
        message = AppsListMessage.new({ include: 'greg\'s buildpack' })
        expect(message).not_to be_valid
      end

      describe 'order_by' do
        it 'allows name' do
          message = AppsListMessage.new(order_by: 'name')
          expect(message).to be_valid
        end
      end

      describe 'validations' do
        it 'validates names is an array' do
          message = AppsListMessage.new names: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:names].length).to eq 1
        end

        it 'validates guids is an array' do
          message = AppsListMessage.new guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:guids].length).to eq 1
        end

        it 'validates organization_guids is an array' do
          message = AppsListMessage.new organization_guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:organization_guids].length).to eq 1
        end

        it 'validates space_guids is an array' do
          message = AppsListMessage.new space_guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:space_guids].length).to eq 1
        end
      end
    end
  end
end
