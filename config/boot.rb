ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
$LOAD_PATH.unshift(File.expand_path('../../app', __FILE__))
$LOAD_PATH.unshift(File.expand_path('../../middleware', __FILE__))

require 'bundler/setup'
