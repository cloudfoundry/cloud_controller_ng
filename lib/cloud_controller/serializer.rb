module VCAP::CloudController::Serializer
  extend ActiveSupport::Concern

  module ClassMethods
    def serializes_via_json(accessor_method_name)
      define_method "#{accessor_method_name}_with_serialization" do
        string = send("#{accessor_method_name}_without_serialization")
        return if string.blank?

        begin
          MultiJson.load string
        rescue MultiJson::ParseError => e
          logger = Steno.logger('cc.serializer')
          logger.error("Failed to deserialize #{guid} for object type #{to_s}. Trying to deserialize #{string.dump}")
          raise
        end
      end
      alias_method "#{accessor_method_name}_without_serialization", accessor_method_name
      alias_method accessor_method_name, "#{accessor_method_name}_with_serialization"

      define_method "#{accessor_method_name}_with_serialization=" do |arg|
        send("#{accessor_method_name}_without_serialization=", MultiJson.dump(arg))
      end
      alias_method "#{accessor_method_name}_without_serialization=", "#{accessor_method_name}="
      alias_method "#{accessor_method_name}=", "#{accessor_method_name}_with_serialization="
    end
  end
end
