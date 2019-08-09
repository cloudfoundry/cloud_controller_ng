module VCAP::CloudController
  class IncludeDecoratorRegistry
    class << self
      def register(decorator)
        decorators[decorator.include_name] = decorator
      end

      def for_include(resource_name)
        decorators[resource_name]
      end

      private

      def decorators
        @decorators ||= {}
      end
    end
  end
end
