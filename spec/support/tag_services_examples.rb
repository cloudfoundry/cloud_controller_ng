module ServicesExampleGroup
  def self.included(klass)
    klass.metadata[:team] = "services"
  end
end

RSpec.configure do |config|
  [
    %w[spec services],
    %w[spec (controllers|models|repositories) services],
    %w[spec acceptance],
  ].each do |dir_parts|
    escaped_path = Regexp.compile(dir_parts.join('[\\\/]') + '[\\\/]')
    config.include(ServicesExampleGroup, example_group: {file_path: escaped_path})
  end
end
