require "rspec/version"

unless RSpec::Version::STRING == "2.12.0"
  throw "Make sure monkey patches below are still needed"
end

RSpec::Core::Let::ExampleMethods.class_eval do
  def __memoized
    throw <<-MSG unless example
      It appears that you are calling variable defined via let from before :all block.
      This causes test pollution between individual examples since memoized variables
      are not properly cleaned up.
    MSG

    @__memoized ||= {}
  end
end
