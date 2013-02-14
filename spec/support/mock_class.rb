module MockClass
  module Methods
    # Safely override existing method
    def overrides(name, &blk)
      _check_instance_method_exists!(name)

      # method made from blk will have different parameters from blk parameters
      alias_method "overriden_#{name}", name
      overriden_method = instance_method("overriden_#{name}")

      define_method(name, &blk)
      replacement_method = instance_method(name)

      unless replacement_method.parameters == overriden_method.parameters
        raise <<-ERROR
          Instance method parameters for '#{name}' do not match overriden method's parameters:
            New: #{replacement_method.parameters}
                 (on #{blk.source_location.join(":")})
            Old: #{overriden_method.parameters}
                 (on #{overriden_method.source_location.join(":")})
        ERROR
      end
    end

    # Add helper method to use in tests
    def add(name, &blk)
      _check_instance_method_does_not_exist!(name)
      define_method(name, &blk)
    end

    private

    def _check_instance_method_exists!(name)
      raise "Public instance method '#{name}' is not defined on class '#{self.name}'" \
        unless _instance_methods_to_check(name).include?(name.to_sym)
    end

    def _check_instance_method_does_not_exist!(name)
      raise "Public instance method '#{name}' is already defined on class '#{self.name}'" \
        if _instance_methods_to_check(name).include?(name.to_sym)
    end

    def _instance_methods_to_check(name)
      methods = (name == :initialize) ? private_instance_methods : public_instance_methods
    end
  end

  def self.define(mock_class_name, klass, &blk)
    mock_class = Class.new(klass) do
      extend Methods
      instance_eval(&blk)
    end

    Kernel.const_set(mock_class_name, mock_class)
  end
end
