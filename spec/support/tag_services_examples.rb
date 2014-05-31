require File.expand_path("escaped_path.rb", File.dirname(__FILE__))

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
  ].each do |parts|
    config.include(ServicesExampleGroup, example_group: {file_path: EscapedPath.join(parts)})
  end
end
