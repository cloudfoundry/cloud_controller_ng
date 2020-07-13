# Allows making assertions like:
#   .to raise_api_error(:UniquenessError, "some-message")
# or like:
#   .to raise_api_error(:UniquenessError)
# If only the error name is given, the additional arguments will not be considered
# when matching API errors. This allows slightly more relaxed assertions.
RSpec::Matchers.define :raise_api_error do |api_error_name, *api_error_args|
  build_api_error_matcher(CloudController::Errors::ApiError, api_error_name, *api_error_args)
end

# Similar to the above, but looks for a Errors::V3::ApiError instead of Errors::ApiError
RSpec::Matchers.define :raise_v3_api_error do |api_error_name, *api_error_args|
  build_api_error_matcher(CloudController::Errors::V3::ApiError, api_error_name, *api_error_args)
end

def build_api_error_matcher(error_class, api_error_name, *api_error_args)
  supports_block_expectations

  match do |actual|
    actual.call
  rescue error_class => actual_api_error
    @actual_api_error = actual_api_error
    expected_error = error_class.new_from_details(api_error_name, *api_error_args)

    if api_error_args.empty?
      expected_error.name == actual_api_error.name
    else
      expected_error == actual_api_error
    end
  rescue => other_error
    @other_error = other_error
  end

  failure_message do
    message = "expected block to raise a #{error_class} with:\n" \
      "  name: #{api_error_name}\n" \
      "  args: #{api_error_args}\nbut "

    message += if @actual_api_error
                 "it raised a #{error_class} with:\n" \
                   "  name: #{@actual_api_error.name}\n" \
                   "  args: #{@actual_api_error.args}"
               elsif @other_error
                 "it raised #{@other_error}"
               else
                 'it did not raise'
               end

    message
  end
end
