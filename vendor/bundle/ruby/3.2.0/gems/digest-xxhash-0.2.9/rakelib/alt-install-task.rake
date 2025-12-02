require 'singleton'

# Provides an alternate implementation of 'install' and 'install:local'.
#
# This mainly allows options to be forwarded to `gem install`.
#
class AltInstallTask < Rake::TaskLib
  module GemName
    def gem_name
      gemspec = Bundler::GemHelper.gemspec
      "#{gemspec.name}-#{gemspec.version}.gem"
    end
  end

  module TaskComment
    include GemName

    def comment
      comment = "Build and install #{gem_name} into system gems"
      comment += " without network access" if name.to_s == "install:local"
      comment
    end

    def full_comment
      comment + "."
    end
  end

  include Singleton
  include GemName

  def initialize
    define
  end

  def define
    [:install, :"install:local"].each do |name|
      task(name).clear.enhance([:build]){ |task| execute_task(task) }
          .singleton_class.prepend(TaskComment)
    end
  end

private
  def pkg_dir
    @pkg_dir ||= File.join(Bundler::GemHelper.instance.base, "pkg")
  end

  def execute_task(task)
    built_gem = File.join(pkg_dir, gem_name)
    raise "Gem '#{built_gem}' unexpectedly doesn't exist." unless File.exist? built_gem
    gem_command = (ENV["GEM_COMMAND"].shellsplit rescue nil) || ["gem"]
    opts = ARGV.select{ |e| e =~ /\A--?/ }
    opts.unshift "--local" if task.name.to_s == "install:local"
    Process.wait spawn(*gem_command, "install", built_gem, *opts)
  end
end

AltInstallTask.instance
