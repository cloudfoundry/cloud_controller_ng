SPEC_HELPER_LOADED = true
require 'rubygems'
require 'mock_redis'
require 'spec_helper_helper'

begin
  require 'spork'
  # uncomment the following line to use spork with the debugger
  # require 'spork/ext/ruby-debug'

  run_spork = !`ps | grep spork | grep -v grep`.empty?
rescue LoadError
  run_spork = false
end

if run_spork
  Spork.prefork do
    # Loading more in this block will cause your tests to run faster. However,
    # if you change any configuration or code from libraries loaded here, you'll
    # need to restart spork for it to take effect.
    SpecHelperHelper.init
  end
  Spork.each_run do
    # This code will be run each time you run your specs.
    SpecHelperHelper.each_run
  end
else
  SpecHelperHelper.init
  SpecHelperHelper.each_run
end
