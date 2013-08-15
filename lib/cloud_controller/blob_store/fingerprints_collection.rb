class FingerprintsCollection
  def initialize(fingerprints)
    @fingerprints = fingerprints
  end

  def each_sha(&block)
    @fingerprints.each do |fingerprint|
      block.yield fingerprint["sha1"]
    end
  end
end