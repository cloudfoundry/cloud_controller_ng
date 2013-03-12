require "active_support/core_ext/hash"

module VCAP::CloudController::Models
  class Snapshot < Struct.new(:id, :state)
    def self.from_json(json)
      attrs = Yajl::Parser.parse(json)
      snapshot = attrs.fetch('snapshot')
      new(snapshot)
    end

    def self.many_from_json(json)
      Yajl::Parser.parse(json).fetch('snapshots').collect do |snapshot_attrs|
        new(snapshot_attrs.fetch('snapshot'))
      end
    end

    def initialize(attrs)
      attrs = attrs.symbolize_keys
      self.id = attrs.fetch(:id)
      self.state = attrs.fetch(:state)
    end
  end
end
