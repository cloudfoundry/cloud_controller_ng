require 'spec_helper'
require 'builders/app_create_request_builder'

module VCAP::CloudController
  describe AppCreateRequestBuilder do
    let(:request_builder) { AppCreateRequestBuilder.new }
    context 'lifecycle' do
      let(:default_buildpack) { nil }
      let(:default_stack) { Stack.default.name }
      context 'buildpack' do
        let(:stack) { Stack.make(name: 'some-valid-stack') }

        context 'when the user requests a stack and a buildpack' do
          let(:params) {
            {
              'environment_variables' => {
                'CUSTOM_ENV_VAR' => 'hello'
              },
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => 'http://github.com/myorg/awesome-buildpack',
                  'stack' => stack.name
                }
              }
            }
          }
          let(:desired_assembled_request) {
            {
              'environment_variables' => {
                'CUSTOM_ENV_VAR' => 'hello'
              },
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => 'http://github.com/myorg/awesome-buildpack',
                  'stack' => stack.name
                }
              }
            }
          }

          it 'uses the user-specified lifecycle data' do
            assembled_request = request_builder.build(params)
            expect(assembled_request).to eq(desired_assembled_request)
          end
        end

        context 'when the user requests only a stack' do
          let(:params) {
            {
              'environment_variables' => {
                'CUSTOM_ENV_VAR' => 'hello'
              },
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                  'stack' => stack.name
                }
              }
            }
          }
          let(:desired_assembled_request) {
            {
              'environment_variables' => {
                'CUSTOM_ENV_VAR' => 'hello'
              },
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => default_buildpack,
                  'stack' => stack.name
                }
              }
            }
          }

          it 'uses the user-specified stack and the default buildpack' do
            assembled_request = request_builder.build(params)
            expect(assembled_request).to eq(desired_assembled_request)
          end
        end

        context 'when the user requests only a buildpack' do
          let(:params) {
            {
              'environment_variables' => {
                'CUSTOM_ENV_VAR' => 'hello'
              },
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => 'http://github.com/myorg/awesome-buildpack'
                }
              }
            }
          }
          let(:desired_assembled_request) {
            {
              'environment_variables' => {
                'CUSTOM_ENV_VAR' => 'hello'
              },
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => 'http://github.com/myorg/awesome-buildpack',
                  'stack' => default_stack
                }
              }
            }
          }

          it 'uses the default stack and specified buildpack' do
            assembled_request = request_builder.build(params)
            expect(assembled_request).to eq(desired_assembled_request)
          end
        end

        context 'when the user does not request the lifecycle' do
          let(:params) {
            {
              'environment_variables' => {
                'CUSTOM_ENV_VAR' => 'hello'
              }
            }
          }
          let(:desired_assembled_request) {
            {
              'environment_variables' => {
                'CUSTOM_ENV_VAR' => 'hello'
              },
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => default_buildpack,
                  'stack' => default_stack
                }
              }
            }
          }
          it 'fills in everything' do
            assembled_request = request_builder.build(params)
            expect(assembled_request).to eq(desired_assembled_request)
          end
        end
        context 'when lifecycle is provided but data is empty' do
          let(:params) {
            {
              'environment_variables' => {
                'CUSTOM_ENV_VAR' => 'hello'
              },
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                }
              }
            }
          }
          let(:desired_assembled_request) {
            {
              'environment_variables' => {
                'CUSTOM_ENV_VAR' => 'hello'
              },
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => default_buildpack,
                  'stack' => default_stack
                }
              }
            }
          }
          it 'fills in the default data hash' do
            assembled_request = request_builder.build(params)
            expect(assembled_request).to eq(desired_assembled_request)
          end
        end
        context 'when lifecycle is provided without the data key' do
          let(:params) {
            {
              'environment_variables' => {
                'CUSTOM_ENV_VAR' => 'hello'
              },
              'lifecycle' => {
                'type' => 'buildpack'
              }
            }
          }
          let(:desired_assembled_request) {
            {
              'environment_variables' => {
                'CUSTOM_ENV_VAR' => 'hello'
              },
              'lifecycle' => {
                'type' => 'buildpack'
              }
            }
          }
          it 'does not replace anything' do
            assembled_request = request_builder.build(params)
            expect(assembled_request).to eq(desired_assembled_request)
          end
        end
      end
    end
  end
end
