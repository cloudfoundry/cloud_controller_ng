# frozen_string_literal: true

# Inlined from https://github.com/dnagir/allowy
# See lib/allowy/README.md for details

module Allowy
  # Registry maps objects to their corresponding Access classes.
  # Given a Space object, it finds SpaceAccess class automatically.
  class Registry
    def initialize(ctx, options={})
      options.assert_valid_keys(:access_suffix)
      @context = ctx
      @registry = {}
      @options = options
    end

    def access_control_for!(subject)
      ac = access_control_for(subject)
      raise UndefinedAccessControl.new("Please define Access Control class for #{subject.inspect}") unless ac

      ac
    end

    def access_control_for(subject)
      # Try subject as decorated object
      clazz = class_for(subject.class.source_class.name) if subject.class.respond_to?(:source_class)

      # Try subject as an object
      clazz ||= class_for(subject.class.name)

      # Try subject as a class
      clazz = class_for(subject.name) if !clazz && subject.is_a?(Class)

      return unless clazz

      # create a new instance or return existing
      @registry[clazz] ||= clazz.new(@context)
    end

    private

    def class_for(name)
      "#{name}#{access_suffix}".safe_constantize
    end

    def access_suffix
      @options.fetch(:access_suffix, 'Access')
    end
  end
end
