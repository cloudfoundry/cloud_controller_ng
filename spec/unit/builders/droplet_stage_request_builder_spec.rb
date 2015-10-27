require 'spec_helper'
require 'builders/droplet_stage_request_builder'

module VCAP::CloudController
  describe DropletStageRequestBuilder do
    let(:request_builder) { DropletStageRequestBuilder.new }
    context 'lifecycle' do
      let(:app_model) { AppModel.make }
      let!(:lifecycle_data) { BuildpackLifecycleDataModel.make(app: app_model) }
      let(:default_buildpack) { lifecycle_data.buildpack }
      let(:default_stack) { lifecycle_data.stack }

      context 'data' do
        it 'does not supply a default if data is not provided, but lifecycle is' do
          params = {
            'lifecycle' => {}
          }

          assembled_request = request_builder.build(params, app_model.lifecycle_data)
          expect(assembled_request['lifecycle']['data']).to be(nil)
        end
      end

      context 'type' do
        let(:stack) { Stack.make(name: 'some-valid-stack') }
        it 'does not supply a default to type' do
          params = {
            'lifecycle' => {
              'data' => {
                'buildpack' => 'http://github.com/myorg/awesome-buildpack',
                'stack' => stack.name
              }
            }
          }

          assembled_request = request_builder.build(params, app_model.lifecycle_data)
          expect(assembled_request['lifecycle']['type']).to be(nil)
        end
      end

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
            assembled_request = request_builder.build(params, app_model.lifecycle_data)
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

          it "uses the user-specified stack and the app's buildpack" do
            assembled_request = request_builder.build(params, app_model.lifecycle_data)
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
            assembled_request = request_builder.build(params, app_model.lifecycle_data)
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
            assembled_request = request_builder.build(params, app_model.lifecycle_data)
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
                'data' => {}
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
            assembled_request = request_builder.build(params, app_model.lifecycle_data)
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
            assembled_request = request_builder.build(params, app_model.lifecycle_data)
            expect(assembled_request).to eq(desired_assembled_request)
          end
        end
      end
    end
  end
end
