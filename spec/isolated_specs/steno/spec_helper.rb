# Steno-specific spec helper
# This file loads steno's support files for its unit tests
# The main spec_helper is loaded by each test file with require 'spec_helper'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |file| require file }

# Ensure steno state is cleaned up after each test to avoid interfering with other tests
RSpec.configure do |config|
  config.after do
    # Reset the Syslog singleton to clear any mocks stored in @syslog and @codec
    Steno::Sink::Syslog.instance.reset! if defined?(Steno::Sink::Syslog)

    # Close the actual syslog connection if open
    Syslog.close if defined?(Syslog) && Syslog.opened?
  end
end
