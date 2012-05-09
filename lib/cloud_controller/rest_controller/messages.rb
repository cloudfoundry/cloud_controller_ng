# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  module Messages
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def define_messages
        [:response, :create, :update].each do |type|
          define_message(type)
        end
      end

      def define_message(type)
        attrs   = attributes
        to_one  = @to_one_relationships ||= []
        to_many = @to_many_relationships ||= []

        klass = Class.new VCAP::RestAPI::Message do
          attrs.each do |name, attr|
            unless attr.exclude_in?(type)
              if (type == :update || (type == :create && attr.default))
                optional name, attr.schema
              else
                required name, attr.schema
              end
            end
          end

          to_one.each do |name, relation|
            unless relation.exclude_in?(type)
              if (type == :update || (type == :create &&
                                      relation.optional_in?(type)))
                optional "#{name}_id", Integer
              else
                required "#{name}_id", Integer
              end

              if type == :response
                optional "#{name}_url", VCAP::RestAPI::Message::HTTPS_URL
              end
            end
          end

          to_many.each do |name, relation|
            unless relation.exclude_in?(type)
              if type == :response
                optional "#{name}_url", VCAP::RestAPI::Message::HTTPS_URL
              else
                optional "#{name}_id", [Integer]
              end
            end
          end
        end

        self.const_set "#{type.to_s.camelize}Message", klass
      end
    end
  end
end
