require 'spec_helper'
require 'messages/app_create_message'

module VCAP::CloudController
  RSpec.describe AppCreateMessage do
    it 'works for the happy path' do
      params =
        {
            name: 'name',
            relationships: { space: { data: { guid: 'space-guid-1' } } },
            metadata: {
                labels: {
                    potato: 'mashed'
                },
                annotations: {
                  happy: 'annotation',
                },
            },
            lifecycle: { type: 'docker', data: {} }
        }
      message = AppCreateMessage.new(params)
      expect(message).to be_valid
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) do
          {
              unexpected: 'foo',
              lifecycle: {
                  type: 'buildpack',
                  data: {
                      buildpack: 'nil',
                      stack: Stack.default.name
                  }
              }
          }
        end
        it 'is not valid' do
          message = AppCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when name is not a string' do
        let(:params) do
          {
              name: 32.77,
              lifecycle: {
                  type: 'buildpack',
                  data: {
                      buildpack: 'nil',
                      stack: Stack.default.name
                  }
              }
          }
        end

        it 'is not valid' do
          message = AppCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:name)).to include('must be a string')
        end
      end

      context 'when environment_variables is not an object' do
        let(:params) do
          {
              name: 'name',
              environment_variables: 'potato',
              relationships: { space: { data: { guid: 'guid' } } },
              lifecycle: {
                  type: 'buildpack',
                  data: {
                      buildpack: 'nil',
                      stack: Stack.default.name
                  }
              }
          }
        end

        it 'is not valid' do
          message = AppCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:environment_variables)).to include('must be an object')
        end
      end

      describe 'relationships' do
        context 'when relationships is malformed' do
          let(:params) do
            {
                name: 'name',
                relationships: 'malformed shizzle',
                lifecycle: {
                    type: 'buildpack',
                    data: {
                        buildpack: 'nil',
                        stack: Stack.default.name
                    }
                }
            }
          end

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("'relationships' is not an object")
          end
        end

        context 'when relationships is missing' do
          let(:params) do
            {
                name: 'name',
                lifecycle: {
                    type: 'buildpack',
                    data: {
                        buildpack: 'nil',
                        stack: Stack.default.name
                    }
                }
            }
          end

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("'relationships' is not an object")
          end
        end

        context 'when relationships is not an object' do
          let(:params) do
            {
                name: 'name',
                relationships: 'barney',
                lifecycle: {
                    type: 'buildpack',
                    data: {
                        buildpack: 'nil',
                        stack: Stack.default.name
                    }
                }
            }
          end

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("'relationships' is not an object")
          end
        end

        context 'when space is missing' do
          let(:params) do
            {
                name: 'name',
                relationships: {},
                lifecycle: {
                    type: 'buildpack',
                    data: {
                        buildpack: 'nil',
                        stack: Stack.default.name
                    }
                }
            }
          end

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("'relationships' must include one or more valid relationships")
          end
        end

        context 'when space has an invalid guid' do
          let(:params) do
            {
                name: 'name',
                relationships: { space: { data: { guid: 32 } } },
                lifecycle: {
                    type: 'buildpack',
                    data: {
                        buildpack: nil,
                        stack: Stack.default.name
                    }
                }
            }
          end

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships).any? { |e| e.include?('Space guid') }).to be(true)
          end
        end

        context 'when space is malformed' do
          let(:params) do
            {
                name: 'name',
                relationships: { space: 'asdf' },
                lifecycle: {
                    type: 'buildpack',
                    data: {
                        buildpack: nil,
                        stack: Stack.default.name
                    }
                }
            }
          end

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships).any? { |e| e.include?('Space must be structured like') }).to be(true)
          end
        end

        context 'when additional keys are present' do
          let(:params) do
            {
                name: 'name',
                relationships: {
                    space: { data: { guid: 'guid' } },
                    other: 'stuff'
                },
                lifecycle: {
                    type: 'buildpack',
                    data: {
                        buildpack: nil,
                        stack: Stack.default.name
                    }
                }
            }
          end

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors[:relationships]).to include("Unknown field(s): 'other'")
          end
        end
      end

      describe 'lifecycle' do
        describe 'lifecycle data validations' do
          context 'when lifecycle data is not provided' do
            let(:params) do
              { lifecycle: { type: 'buildpack' } }
            end

            it 'is not valid' do
              message = AppCreateMessage.new(params)

              expect(message).not_to be_valid
              expect(message.errors_on(:lifecycle_data)).to include('must be an object')
            end
          end

          context 'when lifecycle data is not an object' do
            let(:params) do
              { lifecycle: { type: 'buildpack', data: 'blah blah' } }
            end

            it 'is not valid' do
              message = AppCreateMessage.new(params)

              expect(message).not_to be_valid
              expect(message.errors_on(:lifecycle_data)).to include('must be an object')
            end
          end
        end

        describe 'lifecycle type validations' do
          context 'when lifecycle type is not a valid type' do
            let(:params) do
              { lifecycle: { data: {}, type: 'woah!' } }
            end

            it 'is not valid' do
              message = AppCreateMessage.new(params)

              expect(message).not_to be_valid
              expect(message.errors_on(:lifecycle_type)).to include('is not included in the list: buildpack, docker')
            end
          end

          context 'when lifecycle type is not a string' do
            let(:params) do
              { lifecycle: { data: {}, type: { subhash: 'woah!' } } }
            end

            it 'is not valid' do
              message = AppCreateMessage.new(params)

              expect(message).to_not be_valid
              expect(message.errors_on(:lifecycle_type)).to include('must be a string')
            end
          end
        end
      end
    end
  end
end
