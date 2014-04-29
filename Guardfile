# cc Guardfile
# More info at https://github.com/guard/guard#readme

guard 'rspec', :cli => '--color --format doc --fail-fast', :all_on_start => false, :all_after_pass => false do
  watch(%r{^spec/.+_spec\.rb$})
  watch("lib/cloud_controller/api/app.rb")       { "spec/api/legacy_apps_spec.rb" }
  watch(%r{^lib/(.+)\.rb$})                      { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^lib/cloud_controller/(.+)\.rb$})     { |m| "spec/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }

  # These don't match the exact same dir structure between lib and spec
  watch(%r{^lib/cloud_controller/legacy_api/(.+)\.rb$})   { |m| "spec/api/#{m[1]}_spec.rb" }
  watch(%r{^lib/eventmachine/(.+)\.rb$})   { |m| "spec/#{m[1]}_spec.rb" }
end
