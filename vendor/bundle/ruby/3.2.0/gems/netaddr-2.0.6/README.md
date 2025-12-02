# netaddr
A Ruby library for performing calculations on IPv4 and IPv6 subnets. There is also limited support for EUI addresses.

### Version 1.x
The original netaddr which I created in 2007. My use case then was creating an internal IPAM system for Rackspace.

### Version 2.x
A complete rewrite and totally incompatible with 1.x. My main motivation now is to reduce bug reports resulting from the poor code quality of 1.x.


# Building
To run unit tests, execute the following from the top level directory

	ruby test/run_all.rb

To build the gem, execute the following from the top level directory

	gem build netaddr.gemspec


# Examples
Example code may be found in test/example.rb. This example code runs as part of the unit tests.


# Coding Style
I use the following conventions:
* I use tabs for indention since tabs make it really easy to adjust indention widths on the fly.
* I do not follow rigid limits on line lengths. My editor auto-wraps so I add a line break where it feels appropriate.
* I'm not a fan of obfuscation. I prefer clear code over fancy code.
