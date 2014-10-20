require 'spec_helper'
require 'presenters/v3/process_presenter'

module VCAP::CloudController
  describe ProcessPresenter do
    it "presents process fields" do
      VCAP::CloudController::Space.make(guid: 'space-guid')
      VCAP::CloudController::Stack.make(guid: 'stack-guid')
      process_model  = ProcessFactory.make
      process = AppProcess.new(process_model)

      result = ProcessPresenter.new(process).present
      expect(result[:guid]).to eq(process.guid)
    end
  end
end
