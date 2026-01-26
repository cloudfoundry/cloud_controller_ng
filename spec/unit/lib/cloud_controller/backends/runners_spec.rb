require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Runners do
    subject(:runners) { Runners.new(config) }

    let(:config) do
      Config.new({
                   staging: {
                     timeout_in_seconds: 90
                   }
                 })
    end

    describe '#runner_for_process' do
      subject(:runner) { runners.runner_for_process(process) }

      context 'when the app is configured to run on Diego' do
        let(:process) { ProcessModelFactory.make(diego: true) }

        it 'returns a Diego runner' do
          expect(runner).to be_a(Diego::Runner)
        end

        context 'when the app has a docker image' do
          let(:process) { ProcessModelFactory.make(:docker, docker_image: 'foobar') }

          it 'finds a diego backend' do
            expect(runner).to be_a(Diego::Runner)
          end
        end
      end
    end
  end
end
