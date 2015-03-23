module VCAP::CloudController::Serializer
  extend ActiveSupport::Concern

  module ClassMethods
    def serializes_via_json(accessor_method_name)
      define_method "#{accessor_method_name}_with_serialization" do
        string = self.send("#{accessor_method_name}_without_serialization")
        return if string.blank?
        MultiJson.load string
      end
      alias_method_chain accessor_method_name, 'serialization'
      define_method "#{accessor_method_name}_with_serialization=" do |arg|
        self.send("#{accessor_method_name}_without_serialization=", MultiJson.dump(arg))
      end
      alias_method_chain "#{accessor_method_name}=", 'serialization'
    end
  end
end
