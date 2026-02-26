# Steno-specific spec helper
# This file loads steno's support files for its unit tests
# The main spec_helper is loaded by each test file with require 'spec_helper'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |file| require file }

# Ensure syslog is closed after each steno test to avoid interfering with other tests
RSpec.configure do |config|
  config.after do
    Syslog.close if defined?(Syslog) && Syslog.opened?
  end
end
