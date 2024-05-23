class ApiPresenter
  def initialize(object)
    @object = object
  end

  def to_hash
    {
      metadata: metadata_hash,
      entity: entity_hash
    }
  end

  def to_json(*_args)
    Oj.dump(to_hash, mode: :compat)
  end

  protected

  def metadata_hash
    {
      guid: @object.guid,
      created_at: @object.created_at.iso8601,
      updated_at: @object.updated_at.try(:iso8601)
    }
  end

  def entity_hash
    {}
  end
end
