require 'spec_helper'
require 'builders/droplet_stage_request_builder'

module VCAP::CloudController
  describe DropletStageRequestBuilder do
    let(:request_builder) { described_class.new }
    let(:app_model) { AppModel.make }
    let!(:lifecycle_data) { BuildpackLifecycleDataModel.make(app: app_model) }

    context 'buildpack lifecycle' do
      let(:default_buildpack) { lifecycle_data.buildpack }
      let(:default_stack) { lifecycle_data.stack }
      let(:requested_stack) { Stack.make(name: 'some-valid-stack') }

      context 'when data is not provided' do
        let(:request_body) { { 'lifecycle' => {} } }

        it 'does not supply default lifecycle data' do
          assembled_request = request_builder.build(request_body, app_model.lifecycle_data)
          expect(assembled_request['lifecycle']['data']).to be(nil)
        end
      end

      context 'when type is not provided' do
        let(:request_body) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'yo what up'
            },
            'lifecycle'             => {
              'data' => {
                'buildpack' => 'http://github.com/myorg/awesome-buildpack',
                'stack'     => requested_stack.name
              }
            }
          }
        end

        let(:desired_assembled_request) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'yo what up'
            },
            'lifecycle'             => {
              'data' => {
                'buildpack' => 'http://github.com/myorg/awesome-buildpack',
                'stack'     => 'some-valid-stack'
              }
            }
          }
        end

        it 'does not supply a default to type' do
          assembled_request = request_builder.build(request_body, app_model.lifecycle_data)
          expect(assembled_request['lifecycle']['type']).to be(nil)
          expect(assembled_request).to eq(desired_assembled_request)
        end
      end

      context 'when the user requests a stack and a buildpack' do
        let(:request_body) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => 'http://github.com/myorg/awesome-buildpack',
                'stack'     => requested_stack.name
              }
            }
          }
        end

        let(:desired_assembled_request) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => 'http://github.com/myorg/awesome-buildpack',
                'stack'     => requested_stack.name
              }
            }
          }
        end

        it 'uses the user-specified lifecycle data' do
          assembled_request = request_builder.build(request_body, app_model.lifecycle_data)
          expect(assembled_request).to eq(desired_assembled_request)
        end
      end

      context 'when the user requests only a stack' do
        let(:request_body) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'stack' => requested_stack.name
              }
            }
          }
        end

        let(:desired_assembled_request) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => default_buildpack,
                'stack'     => requested_stack.name
              }
            }
          }
        end

        it "uses the user-specified stack and the app's buildpack" do
          assembled_request = request_builder.build(request_body, app_model.lifecycle_data)
          expect(assembled_request).to eq(desired_assembled_request)
        end
      end

      context 'when the user requests only a buildpack' do
        let(:request_body) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => 'http://github.com/myorg/awesome-buildpack'
              }
            }
          }
        end

        let(:desired_assembled_request) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => 'http://github.com/myorg/awesome-buildpack',
                'stack'     => default_stack
              }
            }
          }
        end

        it 'uses the default stack and specified buildpack' do
          assembled_request = request_builder.build(request_body, app_model.lifecycle_data)
          expect(assembled_request).to eq(desired_assembled_request)
        end
      end

      context 'when the user does not request the lifecycle' do
        let(:request_body) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            }
          }
        end

        let(:desired_assembled_request) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => default_buildpack,
                'stack'     => default_stack
              }
            }
          }
        end

        it 'fills in everything' do
          assembled_request = request_builder.build(request_body, app_model.lifecycle_data)
          expect(assembled_request).to eq(desired_assembled_request)
        end
      end

      context 'when lifecycle is provided but data is empty' do
        let(:request_body) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {}
            }
          }
        end

        let(:desired_assembled_request) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => default_buildpack,
                'stack'     => default_stack
              }
            }
          }
        end

        it 'fills in the default data hash' do
          assembled_request = request_builder.build(request_body, app_model.lifecycle_data)
          expect(assembled_request).to eq(desired_assembled_request)
        end
      end

      context 'when lifecycle is provided without the data key' do
        let(:request_body) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle'             => {
              'type' => 'buildpack'
            }
          }
        end

        let(:desired_assembled_request) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle'             => {
              'type' => 'buildpack'
            }
          }
        end

        it 'does not replace anything' do
          assembled_request = request_builder.build(request_body, app_model.lifecycle_data)
          expect(assembled_request).to eq(desired_assembled_request)
        end
      end
    end

    context 'docker lifecycle' do
      let(:request_body) do
        {
          'environment_variables' => {
            'CUSTOM_ENV_VAR' => 'hello'
          },
          'lifecycle'             => {
            'type' => 'docker',
            'data' => {
              'some' => 'nonsense'
            }
          }
        }
      end

      let(:desired_assembled_request) do
        {
          'environment_variables' => {
            'CUSTOM_ENV_VAR' => 'hello'
          },
          'lifecycle'             => {
            'type' => 'docker',
            'data' => {
              'some' => 'nonsense'
            }
          }
        }
      end

      it 'does not alter anything and passes everything through' do
        assembled_request = request_builder.build(request_body, app_model.lifecycle_data)
        expect(assembled_request).to eq(desired_assembled_request)
      end
    end
  end
end
