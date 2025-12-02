# From http://erniemiller.org/2014/02/05/7-lines-every-gems-rakefile-should-have/
# with some modification.

desc "Project IRB console"
task :console do
  require "bundler"
  Bundler.require(:default, :development)

  # Reload helper to avoid resetting the environment when debugging
  def reload!
    files = $LOADED_FEATURES.select { |feat| feat =~ /\/fog-google\// }
    files.each { |file| load file }
  end

  ARGV.clear
  Pry.start
end
