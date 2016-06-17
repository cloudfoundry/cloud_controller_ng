require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RestController::PreloadedObjectSerializer do
    describe '#serialize' do
      let(:object) { double(:object) }
      let(:presenter) { instance_double(::CloudController::Presenters::V2::DefaultPresenter, to_hash: serialized_object) }
      let(:serialized_object) { double(:hash) }
      let(:opts) { {} }
      let(:controller) { double(:controller) }
      let(:orphans) { double(:orphans) }

      it 'finds calls #to_hash on a presenter for the object' do
        allow(::CloudController::Presenters::V2::PresenterProvider).to receive(:presenter_for).with(object).
          and_return(presenter)
        expect(described_class.new.serialize(controller, object, opts, orphans)).to be(serialized_object)
        expect(presenter).to have_received(:to_hash).with(controller, object, opts, 0, [], orphans)
      end
    end
  end
end
