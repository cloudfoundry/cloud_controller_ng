require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class ResourceMatchPresenter < BasePresenter
    def to_hash
      {
        resources: v3ify(@resource)
      }
    end

    private

    def v3ify(resource)
      fingerprints = MultiJson.load(resource)
      fingerprints.map do |r|
        {
          checksum: { value: r['sha1'] },
          size_in_bytes: r['size'],
          path: r['fn'],
          mode: r['mode']
        }
      end
    end
  end
end
