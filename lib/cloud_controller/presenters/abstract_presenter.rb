class AbstractPresenter
  def initialize(object)
    @object = object
  end

  def to_hash
    {
      metadata: metadata_hash,
      entity: entity_hash
    }
  end

  protected

  def metadata_hash
    {
      guid: @object.guid,
      created_at: @object.created_at.to_s,
      updated_at: @object.updated_at.to_s
    }
  end

  def entity_hash
    {}
  end
end
