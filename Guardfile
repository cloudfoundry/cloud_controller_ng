# ccng Guardfile
# More info at https://github.com/guard/guard#readme

guard 'rspec', :version => 2, :cli => '--color --format doc' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }

  # These don't match the exact same dir structure between lib and spec
  watch(%r{^lib/cloud_controller/legacy_api/(.+)\.rb$})   { |m| "spec/api/#{m[1]}_spec.rb" }
  watch(%r{^lib/eventmachine/(.+)\.rb$})   { |m| "spec/#{m[1]}_spec.rb" }
end

