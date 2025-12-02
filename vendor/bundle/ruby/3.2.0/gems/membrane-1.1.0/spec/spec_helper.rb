require "membrane"

def expect_validation_failure(schema, object, regex)
  expect do
    schema.validate(object)
  end.to raise_error(Membrane::SchemaValidationError, regex)
end
