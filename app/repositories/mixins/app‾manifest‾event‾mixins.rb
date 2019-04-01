module VCAP::CloudController
  module AppManifestEventMixins
    private

    def add_manifest_triggered(manifest_triggered, metadata)
      manifest_triggered ? metadata.merge(manifest_triggered: true) : metadata
    end
  end
end
