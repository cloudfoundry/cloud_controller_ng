module VCAP::CloudController::RestController
  # Auto generation of Message classes based on the attributes
  # exposed by a rest endpoint.
  module Messages
    extend ActiveSupport::Concern

    module ClassMethods
      # Define the messages exposed by a rest endpoint.
      def define_messages
        [:create, :update].each do |type|
          define_message(type)
        end
      end

      private

      def define_message(type)
        attrs   = Array(attributes)
        to_one  = @to_one_relationships ||= []
        to_many = @to_many_relationships ||= []

        klass = Class.new VCAP::RestAPI::Message do
          attrs.each do |name, attr|
            unless attr.exclude_in?(type)
              if type == :update
                optional name, attr.schema, &attr.block
              elsif type == :create && attr.has_default?
                optional name, attr.schema, attr.default, &attr.block
              else
                required name, attr.schema, &attr.block
              end
            end
          end

          to_one.each do |name, relation|
            unless relation.exclude_in?(type)
              if type == :update || (type == :create && relation.optional_in?(type))
                optional "#{name}_guid", String
              else
                required "#{name}_guid", String
              end
            end
          end

          to_many.each do |name, relation|
            unless relation.exclude_in?(type)
              optional "#{name.to_s.singularize}_guids", [String]
            end
          end
        end

        # grep-friendly location where CreateMessage and UpdateMessage are declared
        self.const_set "#{type.to_s.camelize}Message", klass
      end
    end
  end
end
