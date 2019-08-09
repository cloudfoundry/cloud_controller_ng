require 'decorators/include_decorator_registry'

module VCAP::CloudController
  module IncludeDecoratorMixin
    def decorators_for_include(include)
      include ||= []
      include.map { |include_name| IncludeDecoratorRegistry.for_include(include_name) }
    end
  end
end
