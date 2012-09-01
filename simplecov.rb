require "simplecov-rcov"
require "simplecov"
# RCov Formatter's output path is hard coded to be "rcov" under
# SimpleCov.coverage_path
SimpleCov.coverage_dir(File.join("spec", "artifacts"))
SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/migrations/"
  add_filter '/vendor\/bundle/'
end

