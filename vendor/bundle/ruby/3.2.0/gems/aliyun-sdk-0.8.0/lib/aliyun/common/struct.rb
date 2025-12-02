# -*- encoding: utf-8 -*-

module Aliyun
  module Common

    # Common structs used. It provides a 'attrs' helper method for
    # subclass to define its attributes. 'attrs' is based on
    # attr_reader and provide additional functionalities for classes
    # that inherits Struct::Base :
    # * the constuctor is provided to accept options and set the
    #   corresponding attibute automatically
    # * the #to_s method is rewrite to concatenate the defined
    #   attributes keys and values
    # @example
    #   class X < Struct::Base
    #     attrs :foo, :bar
    #   end
    #
    #   x.new(:foo => 'hello', :bar => 'world')
    #   x.foo # == "hello"
    #   x.bar # == "world"
    #   x.to_s # == "foo: hello, bar: world"
    module Struct
      class Base
        module AttrHelper
          def attrs(*s)
            define_method(:attrs) {s}
            attr_reader(*s)
          end
        end

        extend AttrHelper

        def initialize(opts = {})
          extra_keys = opts.keys - attrs
          unless extra_keys.empty?
            fail Common::Exception,
                 "Unexpected extra keys: #{extra_keys.join(', ')}"
          end

          attrs.each do |attr|
            instance_variable_set("@#{attr}", opts[attr])
          end
        end

        def to_s
          attrs.map do |attr|
            v = instance_variable_get("@#{attr}")
            "#{attr.to_s}: #{v}"
          end.join(", ")
        end
      end # Base
    end # Struct

  end # Common
end # Aliyun
