module VCAP::CloudController::Validators
  class ArrayValidator < ActiveModel::EachValidator
    def validate_each(record, attr_name, value)
      record.errors.add(attr_name, 'is not an array') unless value.is_a? Array
    end
  end
end
