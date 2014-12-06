require 'spec_helper'
require 'presenters/v3/process_presenter'

module VCAP::CloudController
  describe ProcessPresenter do
    describe '#present_json' do
      it 'presents the process as json' do
        process_model = AppFactory.make
        process       = AppProcess.new(process_model)

        json_result = ProcessPresenter.new.present_json(process)
        result      = MultiJson.load(json_result)

        expect(result['guid']).to eq(process.guid)
      end
    end

    describe '#present_json_list' do
      it 'presents the processes as a json array' do
        process_model1 = AppFactory.make
        process_model2 = AppFactory.make

        json_result = ProcessPresenter.new.present_json_list([process_model1, process_model2])
        result      = MultiJson.load(json_result)

        guids = result.collect { |process_json| process_json['guid'] }
        expect(guids).to eq([process_model1.guid, process_model2.guid])
      end
    end
  end
end
