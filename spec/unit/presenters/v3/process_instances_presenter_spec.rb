require 'spec_helper'
require 'presenters/v3/process_instances_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe ProcessInstancesPresenter do
    let(:process) { VCAP::CloudController::ProcessModel.make }
    let(:instances) do
      {
        0 => { state: 'RUNNING', since: 111 },
        1 => { state: 'STARTING', since: 222 },
        2 => { state: 'CRASHED', since: 333 }
      }
    end

    subject(:presenter) { ProcessInstancesPresenter.new(instances, process) }

    describe '#to_hash' do
      it 'returns a hash with resources and links' do
        result = presenter.to_hash
        expect(result).to have_key(:resources)
        expect(result).to have_key(:links)
      end

      it 'builds instances with correct structure' do
        resources = presenter.to_hash[:resources]
        expect(resources).to be_an(Array)
        expect(resources.length).to eq(3)

        expect(resources[0]).to eq({ index: 0, state: 'RUNNING', since: 111 })
        expect(resources[1]).to eq({ index: 1, state: 'STARTING', since: 222 })
        expect(resources[2]).to eq({ index: 2, state: 'CRASHED', since: 333 })
      end

      it 'builds correct links' do
        links = presenter.to_hash[:links]
        expect(links[:self][:href]).to eq("#{link_prefix}/v3/processes/#{process.guid}/process_instances")
        expect(links[:process][:href]).to eq("#{link_prefix}/v3/processes/#{process.guid}")
      end

      context 'with empty instances' do
        let(:instances) { {} }

        it 'returns an empty resources array' do
          resources = presenter.to_hash[:resources]
          expect(resources).to eq([])
        end
      end
    end
  end
end
