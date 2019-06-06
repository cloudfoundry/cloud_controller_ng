$LOAD_PATH.push(File.expand_path(File.join(__dir__, '..', 'app')))
$LOAD_PATH.push(File.expand_path(File.join(__dir__, '..', 'lib')))

# So that specs using this helper don't fail with undefined constant error
module VCAP; end
