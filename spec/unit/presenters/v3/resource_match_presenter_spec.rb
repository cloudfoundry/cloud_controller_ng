require 'spec_helper'
require 'presenters/v3/resource_match_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe ResourceMatchPresenter do
    let(:stupid_v2_response_thing) {
      StringIO.new([{
        'sha1' => '002d760bea1be268e27077412e11a320d0f164d3',
        'size' => 32,
        'fn' => 'path/to/file',
        'mode' => '123'
      }].to_json)
    }

    it 'converts the v2ish response to a v3ish ruby data object' do
      presenter = ResourceMatchPresenter.new(stupid_v2_response_thing)
      expect(presenter.to_hash).to eq({
        resources: [
          {
            checksum: { value: '002d760bea1be268e27077412e11a320d0f164d3' },
            size_in_bytes: 32,
            path: 'path/to/file',
            mode: '123'
          }]
      })
    end
  end
end
