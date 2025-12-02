#include <vmstat.h>
#include <hw/posix.h>
#include <hw/statfs.h>
#include <hw/sysctl.h>
#include <hw/mach.h>
#include <hw/bsd.h>

void Init_vmstat() {
  VALUE vmstat = rb_define_module("Vmstat");

/*
 * Below the list of platform implementations. The Platforms in square
 * brackets are implemented in ruby not in c.
 */

// MAC, FreeBSD, [LINUX]
#if defined(VMSTAT_NETWORK_INTERFACES)
  rb_define_singleton_method(vmstat, "network_interfaces", vmstat_network_interfaces, 0);
#endif

// MAC, FreeBSD, [LINUX]
#if defined(VMSTAT_CPU)
  rb_define_singleton_method(vmstat, "cpu", vmstat_cpu, 0);
#endif

// MAC, FreeBSD, [LINUX]
#if defined(VMSTAT_MEMORY)
  rb_define_singleton_method(vmstat, "memory", vmstat_memory, 0);
#endif

// MAC, FreeBSD, LINUX
#if defined(VMSTAT_DISK)
  rb_define_singleton_method(vmstat, "disk", vmstat_disk, 1);
#endif

// MAC, FreeBSD, LINUX
#if defined(VMSTAT_LOAD_AVERAGE)
  rb_define_singleton_method(vmstat, "load_average", vmstat_load_average, 0);
#endif

// MAC, FreeBSD, [LINUX]
#if defined(VMSTAT_BOOT_TIME)
  rb_define_singleton_method(vmstat, "boot_time", vmstat_boot_time, 0);
#endif

// MAC
#if defined(VMSTAT_TASK)
  rb_define_singleton_method(vmstat, "task", vmstat_task, 0);
#endif

// MAC, FreeBSD, LINUX
#if defined(VMSTAT_PAGESIZE)
  rb_define_singleton_method(vmstat, "pagesize", vmstat_pagesize, 0);
#endif
}

