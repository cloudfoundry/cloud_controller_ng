require 'spec_helper'

module VCAP::CloudController
  RSpec.describe IndexStopper do
    let(:runners) { double(:runners, runner_for_app: runner) }
    let(:runner) { double(:runner, stop_index: nil) }
    let(:app) { double(:app, guid: 'app-guid') }

    subject(:index_stopper) { described_class.new(runners) }

    describe '#stop_index' do
      it 'stops the index of the app' do
        allow(runner).to receive(:stop_index)

        index_stopper.stop_index(app, 33)

        expect(runner).to have_received(:stop_index).with(33)
      end
    end
  end
end
