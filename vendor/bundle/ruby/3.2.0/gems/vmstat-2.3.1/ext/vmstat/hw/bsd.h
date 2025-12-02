#if defined(HAVE_SYS_SYSCTL_H) && defined(HAVE_SYS_TYPES_H) && \
    defined(HAVE_SYSCTLBYNAME)
#include <vmstat.h>
#include <sys/sysctl.h>
#include <sys/types.h>

// helper methods
int system_int(const char *);
unsigned int system_uint(const char *);

typedef struct {
  long user;
  long nice;
  long system;
  long intr;
  long idle;
} cpu_time_t;

#ifndef VMSTAT_CPU
#define VMSTAT_CPU
VALUE vmstat_cpu(VALUE self) {
  VALUE cpus = rb_ary_new();
  int cpu_count = system_int("hw.ncpu");
  size_t len = sizeof(cpu_time_t) * cpu_count;
  cpu_time_t * cp_times = ALLOC_N(cpu_time_t, cpu_count);
  cpu_time_t * cp_time;
  int i;
  
  if (sysctlbyname("kern.cp_times", cp_times, &len, NULL, 0) == 0) {
    for (i = 0; i < cpu_count; i++) {
      cp_time = &cp_times[i];
      VALUE cpu = rb_funcall(rb_path2class("Vmstat::Cpu"),
                  rb_intern("new"), 5, ULL2NUM(i),
                                       ULL2NUM(cp_time->user),
                                       ULL2NUM(cp_time->system + cp_time->intr),
                                       ULL2NUM(cp_time->nice),
                                       ULL2NUM(cp_time->idle));
      rb_ary_push(cpus, cpu);
    }
  }

  free(cp_times);
  
  return cpus;
}

int system_int(const char * name) {
  int number;
  size_t number_size = sizeof(number);
  sysctlbyname(name, &number, &number_size, NULL, 0);
  return number;
}
#endif

#ifndef VMSTAT_MEMORY
#define VMSTAT_MEMORY
VALUE vmstat_memory(VALUE self) {
  VALUE memory = rb_funcall(rb_path2class("Vmstat::Memory"),
                 rb_intern("new"), 7, ULL2NUM(system_uint("vm.stats.vm.v_page_size")),
                                      ULL2NUM(system_uint("vm.stats.vm.v_active_count")),
                                      ULL2NUM(system_uint("vm.stats.vm.v_wire_count")),
                                      ULL2NUM(system_uint("vm.stats.vm.v_inactive_count")),
                                      ULL2NUM(system_uint("vm.stats.vm.v_free_count")),
                                      ULL2NUM(system_uint("vm.stats.vm.v_vnodepgsin")),
                                      ULL2NUM(system_uint("vm.stats.vm.v_vnodepgsout")));
  return memory;
}

unsigned int system_uint(const char * name) {
  unsigned int number;
  size_t number_size = sizeof(number);
  if (sysctlbyname(name, &number, &number_size, NULL, 0) == -1) {
    perror("sysctlbyname");
    return -1;
  } else {
    return number;
  }
}
#endif
#endif
