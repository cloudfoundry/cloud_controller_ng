require 'mkmf'

# posix.h
have_header 'unistd.h'
have_func 'getpagesize', 'unistd.h'
have_header 'stdlib.h'
if have_header 'sys/loadavg.h'
  have_func 'getloadavg', 'sys/loadavg.h'
else
  have_func 'getloadavg'
end

# mach.h
have_header 'mach/mach.h'
have_header 'mach/mach_host.h'
have_func 'host_processor_info'
have_func 'mach_host_self'
have_func 'mach_task_self'
have_func 'vm_deallocate'
have_func 'mach_error_string'
have_func 'task_info'
mach_headers = ['mach/mach.h', 'mach/mach_host.h']
have_const 'KERN_SUCCESS', mach_headers
have_const 'TASK_BASIC_INFO', mach_headers
have_const 'HOST_VM_INFO', mach_headers
have_const 'CPU_STATE_MAX', mach_headers
have_const 'PROCESSOR_CPU_LOAD_INFO', mach_headers
have_const 'CPU_STATE_USER', mach_headers
have_const 'CPU_STATE_SYSTEM', mach_headers
have_const 'CPU_STATE_NICE', mach_headers
have_const 'CPU_STATE_IDLE', mach_headers

# statfs.h
have_header 'sys/param.h'
have_header 'sys/mount.h'
have_header 'sys/statfs.h'
have_func 'statfs'
have_struct_member('struct statfs', 'f_type', ['sys/param.h', 'sys/mount.h', 'sys/statfs.h'])
have_struct_member('struct statfs', 'f_fstypename', ['sys/param.h', 'sys/mount.h'])
have_func 'statvfs', ['sys/types.h', 'sys/statvfs.h']
have_struct_member('struct statvfs', 'f_basetype', ['sys/types.h', 'sys/statvfs.h'])

# sysctl.h
sys_headers = ['unistd.h', 'sys/sysctl.h', 'sys/types.h', 'sys/socket.h',
               'net/if.h', 'net/if_types.h']
sys_headers.each { |header| have_header header }
sys_headers << 'net/if_mib.h'

if not have_header('net/if_mib.h')
  puts "-> net/if_mib.h can't be checked individually, apply workaround for macOS mojave"
  have_header 'net/if_mib.h', ['net/if_types.h', 'net/if.h']
end

have_func 'getloadavg'
have_func 'sysctl'
have_type 'struct ifmibdata', sys_headers
have_const 'CTL_NET', sys_headers
have_const 'PF_LINK', sys_headers
have_const 'NETLINK_GENERIC', sys_headers
have_const 'IFMIB_IFDATA', sys_headers
have_const 'IFDATA_GENERAL', sys_headers

have_const 'CTL_KERN', ['sys/sysctl.h', 'sys/types.h']
have_const 'KERN_BOOTTIME', ['sys/sysctl.h', 'sys/types.h']

# bsd.h
# only if we have *bsd like stats check for sysctlbyname
if xsystem 'sysctl vm.stats.vm.v_page_size'
  have_header 'sys/sysctl.h'
  have_header 'sys/types.h'
  have_func 'sysctlbyname'
end

create_header

create_makefile 'vmstat/vmstat'