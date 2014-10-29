require 'spec_helper'
require 'presenters/v3/process_presenter'

module VCAP::CloudController
  describe ProcessPresenter do
    describe '#present_json' do
      it 'presents the process as json' do
        process_model  = AppFactory.make
        process = AppProcess.new(process_model)

        json_result = ProcessPresenter.new(process).present_json
        result = MultiJson.load(json_result)

        expect(result['guid']).to eq(process.guid)
      end
    end
  end
end
