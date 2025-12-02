#if defined(HAVE_MACH_MACH_H)
#include <vmstat.h>
#include <mach/mach.h>
#include <mach/mach_host.h>

#ifndef VMSTAT_CPU
#define VMSTAT_CPU
VALUE vmstat_cpu(VALUE self) {
  VALUE cpus = rb_ary_new();
  processor_info_array_t cpuInfo;
  mach_msg_type_number_t numCpuInfo;
  natural_t numCPUsU = 0U;
  kern_return_t err = host_processor_info(mach_host_self(),
    PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo);

  if(err == KERN_SUCCESS) {
    unsigned i;

    for(i = 0U; i < numCPUsU; ++i) {
      int pos = CPU_STATE_MAX * i;
      VALUE cpu = rb_funcall(rb_path2class("Vmstat::Cpu"),
                  rb_intern("new"), 5, ULL2NUM(i),
                                       ULL2NUM(cpuInfo[pos + CPU_STATE_USER]),
                                       ULL2NUM(cpuInfo[pos + CPU_STATE_SYSTEM]),
                                       ULL2NUM(cpuInfo[pos + CPU_STATE_NICE]),
                                       ULL2NUM(cpuInfo[pos + CPU_STATE_IDLE]));
      rb_ary_push(cpus, cpu);
    }

    err = vm_deallocate(mach_task_self(), (vm_address_t)cpuInfo,
                        (vm_size_t)sizeof(*cpuInfo) * numCpuInfo);
    if (err != KERN_SUCCESS) {
      rb_bug("vm_deallocate: %s\n", mach_error_string(err));
    }
  }
  
  return cpus;
}
#endif

#ifndef VMSTAT_MEMORY
#define VMSTAT_MEMORY
VALUE vmstat_memory(VALUE self) {
  VALUE memory = Qnil;
  vm_size_t pagesize;
  uint host_count = HOST_VM_INFO_COUNT;
  kern_return_t err;
  vm_statistics_data_t vm_stat;
  
  err = host_page_size(mach_host_self(), &pagesize);
  if (err == KERN_SUCCESS) {
    err = host_statistics(mach_host_self(), HOST_VM_INFO,
                          (host_info_t)&vm_stat, &host_count);
    if (err == KERN_SUCCESS) {
      memory = rb_funcall(rb_path2class("Vmstat::Memory"),
               rb_intern("new"), 7, ULL2NUM(pagesize),
                                    ULL2NUM(vm_stat.active_count),
                                    ULL2NUM(vm_stat.inactive_count),
                                    ULL2NUM(vm_stat.wire_count),
                                    ULL2NUM(vm_stat.free_count),
                                    ULL2NUM(vm_stat.pageins),
                                    ULL2NUM(vm_stat.pageouts));
    }

    err = vm_deallocate(mach_task_self(), (vm_address_t)pagesize,
                        (vm_size_t)host_count);
    if (err != KERN_SUCCESS) {
      rb_bug("vm_deallocate: %s\n", mach_error_string(err));
    }
  }

  return memory;
}
#endif

#ifndef VMSTAT_TASK
#define VMSTAT_TASK
VALUE vmstat_task(VALUE self) {
  VALUE task = Qnil;
  struct task_basic_info info;
  kern_return_t err;
  mach_msg_type_number_t size = sizeof(info);

  err = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
  if (err == KERN_SUCCESS) {
    task = rb_funcall(rb_path2class("Vmstat::Task"),
           rb_intern("new"), 4, LONG2NUM(info.virtual_size),
                                LONG2NUM(info.resident_size),
                                LONG2NUM(info.user_time.seconds * 1000 + info.user_time.microseconds),
                                LONG2NUM(info.system_time.seconds * 1000 + info.system_time.microseconds));
  } else {
    rb_bug("task_info: %s\n", mach_error_string(err));
  }

  return task;
}
#endif
#endif
