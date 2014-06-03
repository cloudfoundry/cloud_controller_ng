require 'spec_helper'

module VCAP::CloudController::InstancesReporter
  describe LegacyInstancesReporter do
    let(:app) { VCAP::CloudController::AppFactory.make(:package_hash => "abc", :package_state => "STAGED") }

    describe '#all_instances_for_app' do
      let(:instances) do
        {
          0 => {
            :state => "RUNNING",
            :since => 1,
          },
        }
      end

      before do
        allow(VCAP::CloudController::DeaClient).to receive(:find_all_instances).and_return(instances)
      end

      it 'uses DeaClient to return instances' do
        response = subject.all_instances_for_app(app)

        expect(VCAP::CloudController::DeaClient).to have_received(:find_all_instances).with(app)
        expect(instances).to eq(response)
      end
    end
  end
end