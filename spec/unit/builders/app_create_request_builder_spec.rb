require 'spec_helper'
require 'builders/app_create_request_builder'

module VCAP::CloudController
  describe AppCreateRequestBuilder do
    let(:request_builder) { AppCreateRequestBuilder.new }
    context 'lifecycle' do
      let(:default_buildpack) { nil }
      let(:default_stack) { Stack.default.name }

      it 'does not modify the passed-in params' do
        params = { foo: 'bar' }

        request = request_builder.build(params)

        expect(request).to_not eq(params)
        expect(params).to eq(foo: 'bar')
      end

      let(:stack) { Stack.make(name: 'some-valid-stack') }

      context 'when the lifecycle type is buildpack' do
        let(:params) {
          {
            'lifecycle' => {
              'type' => 'buildpack',
              'data' => lifecycle_data
            }
          }
        }

        context 'and lifecycle data is complete' do
          let(:lifecycle_data) { { 'buildpack' => 'cool-buildpack', 'stack' => 'cool-stack' } }

          it 'uses the user-specified lifecycle data' do
            expect(request_builder.build(params)['lifecycle']['data']).to eq(lifecycle_data)
          end
        end

        context 'and lifecycle data is incomplete' do
          context 'buildpack is missing' do
            let(:lifecycle_data) { { 'stack' => 'my-stack' } }

            it 'uses the user-specified stack and the default buildpack' do
              expect(request_builder.build(params)['lifecycle']['data']).to eq('buildpack' => default_buildpack, 'stack' => 'my-stack')
            end
          end

          context 'stack is missing' do
            let(:lifecycle_data) { { 'buildpack' => 'my-buildpack' } }

            it 'uses the default stack and specified buildpack' do
              expect(request_builder.build(params)['lifecycle']['data']).to eq('buildpack' => 'my-buildpack', 'stack' => Stack.default.name)
            end
          end

          context 'when lifecycle is provided but data is empty' do
            let(:lifecycle_data) { {} }

            it 'fills in the default data hash' do
              expect(request_builder.build(params)['lifecycle']['data']).to eq('buildpack' => default_buildpack, 'stack' => Stack.default.name)
            end
          end

          context 'when the keys are requested but are nil' do
            let(:lifecycle_data) { { 'buildpack' => nil, 'stack' => nil } }

            it 'fills in the stack, but not the buildpack' do
              expect(request_builder.build(params)['lifecycle']['data']).to eq('buildpack' => nil, 'stack' => Stack.default.name)
            end
          end
        end
      end

      context 'when the lifecycle type is not buildpack' do
        let(:params) {
          {
            'lifecycle' => {
              'type' => 'cool-type',
              'data' => { 'cool' => 'data' }
            }
          }
        }

        it 'uses the provided data' do
          expect(request_builder.build(params)['lifecycle']['data']).to eq({ 'cool' => 'data' })
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

      context 'when lifecycle is provided without the data key' do
        let(:params) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle' => {
              'type' => 'buildpack'
            }
          }
        end
        let(:desired_assembled_request) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle' => {
              'type' => 'buildpack'
            }
          }
        end

        it 'does not replace anything' do
          assembled_request = request_builder.build(params)
          expect(assembled_request).to eq(desired_assembled_request)
        end
      end

      context 'when lifecycle is provided without a type' do
        let(:params) do
          {
            'environment_variables' => {
              'CUSTOM_ENV_VAR' => 'hello'
            },
            'lifecycle' => {
              'foo' => 'bar',
              'data' => { 'cool' => 'data' }
            }
          }
        end

        it 'does not replace anything' do
          expect(request_builder.build(params)['lifecycle']).to eq('foo' => 'bar', 'data' => { 'cool' => 'data' })
        end
      end
    end
  end
end
