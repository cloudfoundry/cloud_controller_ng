module CreationOptionsFromObject
  def self.options(obj, opts)
    attribute_names = opts[:required_attributes] | opts.fetch(:db_required_attributes, [])
    create_attribute = opts[:create_attribute]

    attrs = {}
    attribute_names.each do |attr_name|
      v = create_attribute.call(attr_name, obj) if create_attribute
      v ||= obj.send(attr_name)
      attrs[attr_name] = v
    end
    attrs
  end
end