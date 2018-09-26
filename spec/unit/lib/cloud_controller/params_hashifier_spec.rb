require 'spec_helper'
require 'cloud_controller/params_hashifier'

module VCAP::CloudController
  class FakeController
    include VCAP::CloudController::ParamsHashifier

    attr_reader :params

    def initialize(params)
      @params = params
    end
  end

  RSpec.describe ParamsHashifier do
    let(:controller) { FakeController.new(params) }

    before do
      controller.hashify_params
    end

    context 'when the given key is a string' do
      let(:params) { ActionController::Parameters.new({ 'hello' => 'morris' }) }

      it 'processes the rails5 parameters' do
        expect(controller.hashed_params[:hello]).to eq('morris')
        expect(controller.hashed_params['hello']).to eq('morris')
      end
    end

    context 'when the given key is a symbol' do
      let(:params) { ActionController::Parameters.new({ hello: 'morris' }) }

      it 'processes the rails5 parameters' do
        expect(controller.hashed_params[:hello]).to eq('morris')
        expect(controller.hashed_params['hello']).to eq('morris')
      end
    end

    context 'when the params are nested' do
      let(:params) do ActionController::Parameters.new({ array1: ['abc', :def],
                                                         hash1: { abc: 1, def: 2, 'ghi' => 3 },
                                                         cdstrings: 'string1,string2,string3'

                                        })
      end

      it 'processes the rails5 parameters' do
        expect(controller.hashed_params[:array1]).to match_array(['abc', :def])
        expect(controller.hashed_params[:hash1][:abc]).to eq(1)
        expect(controller.hashed_params[:hash1]['ghi']).to eq(3)
        expect(controller.hashed_params[:hash1][:ghi]).to eq(3)
        expect(controller.hashed_params[:cdstrings]).to eq('string1,string2,string3')
      end
    end
  end
end
