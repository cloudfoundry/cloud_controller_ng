require "sequel/model"
module Delayed
  module Serialization
    module Sequel
      def self.configure(klass)
        klass.class_eval do
          if YAML.parser.class.name =~ /syck/i
            yaml_as "tag:ruby.yaml.org,2002:Sequel"
          end
        end
      end

      if YAML.parser.class.name =~ /syck/i
        module ClassMethods
          def yaml_new(klass, tag, val)
            pk = val["values"][klass.primary_key]
            klass[pk] ||
            raise(Delayed::DeserializationError, "Sequel Record not found, class: #{klass} , primary key: #{pk}")
          end
        end
      end

      module InstanceMethods
        if YAML.parser.class.name =~ /syck/i
          def to_yaml_properties
            ["@values"]
          end
        else
          def encode_with(coder)
            coder["values"] = @values
          end

          def init_with(coder)
            @values = coder["values"]
            reload
          rescue ::Sequel::Error
            raise Delayed::DeserializationError, "Sequel Record not found, class: #{self.class.name} , primary key: #{pk}"
          end
        end
      end
    end
  end
end

Sequel::Model.plugin Delayed::Serialization::Sequel
