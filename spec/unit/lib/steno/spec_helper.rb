# Steno-specific spec helper
# This file loads steno's support files for its unit tests
# The main spec_helper is loaded by each test file with require 'spec_helper'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |file| require file }
