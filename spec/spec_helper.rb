SPEC_HELPER_LOADED = true
require 'rubygems'
require 'mock_redis'
require 'spec_helper_helper'

SpecHelperHelper.init
SpecHelperHelper.each_run
