require 'presenters/v2/presenter_provider'

module VCAP::CloudController::RestController
  class PreloadedObjectSerializer
    # Render an object as a hash, using export and security properties
    # set by its controller.
    #
    # @param [RestController] controller Controller for the object being
    # serialized.
    #
    # @param [Sequel::Model] obj Object to encode.
    #
    # @option opts [Integer] :inline_relations_depth Depth to recursively
    # exapend relationships in addition to providing the URLs.
    #
    # @option opts [Integer] :max_inline Maximum number of objects to
    # expand inline in a relationship.
    #
    # @param [Integer] depth The current recursion depth.
    #
    # @param [Hash] orphans A hash to accumulate orphaned inline relationships
    # against, keyed by guid, or nil if inline relationships should be appended to
    # parents instead of being orphaned.
    #
    # @return [Hash] Hash encoding of the object.
    def serialize(controller, obj, opts, orphans=nil)
      presenter = ::CloudController::Presenters::V2::PresenterProvider.presenter_for(obj)
      presenter.to_hash(controller, obj, opts, 0, [], orphans)
    end
  end
end
