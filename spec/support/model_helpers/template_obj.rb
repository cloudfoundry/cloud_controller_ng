module ModelHelpers
  # This is used by the specs to construct an object with known properties
  # that can be used over and over between examples along with regenerating
  # the relevant assocations (via refresh).
  class TemplateObj
    attr_accessor :attributes

    def initialize(klass, attribute_names)
      @klass = klass
      @obj = klass.make
      @attributes = {}
      attribute_names.each do |attr|
        key = if @klass.associations.include?(attr.to_sym)
                "#{attr}_id"
              else
                attr
              end
        rel_attr = attr.to_s.chomp("_id")
        attr = rel_attr if @klass.associations.include?(rel_attr.to_sym)
        @attributes[key] = @obj.send(attr) if @obj.respond_to?(attr)
      end
      hash
    end

    def refresh
      @klass.associations.each do |name|
        next if name.to_s.end_with?("_sti_eager_load")

        association = @obj.send(name)
        ["id", "guid"].each do |k|
          key = "#{name}_#{k}"
          @attributes[key] = association.class.make.send(k) if @attributes[key]
        end
      end
    end
  end
end
