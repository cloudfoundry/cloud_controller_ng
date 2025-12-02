require 'mkmf'

$defs.push('-Wall') if enable_config('all-warnings')
$defs.push('-ggdb3') if enable_config('gdb-info')
$CFLAGS << ' -O0' if enable_config('no-opt')

create_makefile('digest/xxhash')

if enable_config('verbose-mode')
	# This also needs Gem.configuration.really_verbose enabled to work
	# with `gem install`.  The value of Gem.configuration.verbose should
	# be set to anything other than true, false, or nil to enable it.
	# See source code of Gem::ConfigFile class for location of gemrc
	# files and other details.
	#
	# Following is an example configuration in /etc/gemrc.
	# Key needs to be in symbol form.
	#
	# :verbose: "really_verbose"
	#
	File.write('Makefile', "\nV = 1\n", mode: 'a')
end
