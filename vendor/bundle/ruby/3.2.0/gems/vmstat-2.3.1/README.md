# Vmstat [![Build Status](https://secure.travis-ci.org/threez/ruby-vmstat.png)](http://travis-ci.org/threez/ruby-vmstat) [![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/threez/ruby-vmstat)

This is a focused and fast library to get system information like:

* _Memory_ (free, active, ...)
* _Network Interfaces_ (name, in bytes, out bytes, ...)
* _CPU_ (user, system, nice, idle)
* _Load_ Average
* _Disk_ (type, disk path, free bytes, total bytes, ...)
* _Boot Time_
* _Current Task_ (used bytes and usage time *MAC OS X / Linux ONLY*)

*It currently supports:*

* FreeBSD
* MacOS X
* Linux (>= 2.6)
* OpenBSD
* NetBSD
* Solaris/SmartOS

*It might support (but not tested):*

* Older versions of linux

## Installation

Add this line to your application's Gemfile:

    gem 'vmstat'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install vmstat

## Usage

Just require the library and make a snapshot or use the distinct methods to just capture parts of the statistics. For further information have a look at the [rdoc](http://rdoc.info/gems/vmstat/frames).

	require "vmstat"
	
	Vmstat.snapshot # => #<Vmstat::Snapshot:0x007fe5f22df660
	#	 @at=2012-10-09 21:48:57 +0200,
	#	 @boot_time=2012-10-09 18:42:37 +0200,
	#	 @cpus=
	#	  [#<struct Vmstat::Cpu
	#	    num=0,
	#	    user=187167,
	#	    system=144466,
	#	    nice=0,
	#	    idle=786622>,
	#	   #<struct Vmstat::Cpu num=1, user=2819, system=1641, nice=0, idle=1113782>,
	#	   #<struct Vmstat::Cpu num=2, user=158698, system=95186, nice=0, idle=864359>,
	#	   #<struct Vmstat::Cpu num=3, user=2702, system=1505, nice=0, idle=1114035>,
	#	   #<struct Vmstat::Cpu num=4, user=140231, system=78248, nice=0, idle=899764>,
	#	   #<struct Vmstat::Cpu num=5, user=2468, system=1314, nice=0, idle=1114460>,
	#	   #<struct Vmstat::Cpu num=6, user=120764, system=66284, nice=0, idle=931195>,
	#	   #<struct Vmstat::Cpu num=7, user=2298, system=1207, nice=0, idle=1114737>],
	#	 @disks=
	#	  [#<struct Vmstat::Disk
	#	    type=:hfs,
	#	    origin="/dev/disk0s2",
	#	    mount="/",
	#	    block_size=4096,
	#	    free_blocks=51470668,
	#	    available_blocks=51406668,
	#	    total_blocks=61069442>],
	#	 @load_average=
	#	  #<struct Vmstat::LoadAverage
	#	   one_minute=1.74072265625,
	#	   five_minutes=1.34326171875,
	#	   fifteen_minutes=1.1845703125>,
	#	 @memory=
	#	  #<struct Vmstat::Memory
	#	   pagesize=4096,
	#	   wired=1037969,
	#	   active=101977,
	#	   inactive=484694,
	#	   free=470582,
	#	   pageins=102438,
	#	   pageouts=0>,
	#	 @network_interfaces=
	#	  [#<struct Vmstat::NetworkInterface
	#	    name=:lo0,
	#	    in_bytes=6209398,
	#	    in_errors=0,
	#	    in_drops=0,
	#	    out_bytes=6209398,
	#	    out_errors=0,
	#	    type=24>,
	#	   #<struct Vmstat::NetworkInterface
	#	    name=:gif0,
	#	    in_bytes=0,
	#	    in_errors=0,
	#	    in_drops=0,
	#	    out_bytes=0,
	#	    out_errors=0,
	#	    type=55>,
	#	   #<struct Vmstat::NetworkInterface
	#	    name=:stf0,
	#	    in_bytes=0,
	#	    in_errors=0,
	#	    in_drops=0,
	#	    out_bytes=0,
	#	    out_errors=0,
	#	    type=57>,
	#	   #<struct Vmstat::NetworkInterface
	#	    name=:en0,
	#	    in_bytes=1321276010,
	#	    in_errors=0,
	#	    in_drops=0,
	#	    out_bytes=410426678,
	#	    out_errors=0,
	#	    type=6>,
	#	   #<struct Vmstat::NetworkInterface
	#	    name=:p2p0,
	#	    in_bytes=0,
	#	    in_errors=0,
	#	    in_drops=0,
	#	    out_bytes=0,
	#	    out_errors=0,
	#	    type=6>],
	#	 @task=
	#	  #<struct Vmstat::Task
	#	   suspend_count=0,
	#	   virtual_size=2551554048,
	#	   resident_size=19628032,
	#	   user_time_ms=28,
	#	   system_time_ms=83>>

## Todo

* Swap information
* Support more platforms (hp ux, aix, ...)
* Optimize performance for OpenBSD, NetBSD using `uvmexp` etc. directly
* Optimize performance for solaris, smartos using `kstat` etc. directly
* Server performance/system information (open file handles, cache sizes, number of inodes ...)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
