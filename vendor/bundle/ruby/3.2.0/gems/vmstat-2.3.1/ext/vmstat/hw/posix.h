#if defined(HAVE_UNISTD_H)
#include <unistd.h>
#endif

#if defined(HAVE_GETPAGESIZE)
#ifndef VMSTAT_PAGESIZE
#define VMSTAT_PAGESIZE
VALUE vmstat_pagesize(VALUE self) {
  return INT2NUM(getpagesize());
}
#endif
#endif

#if defined(HAVE_SYS_LOADAVG_H)
#include <sys/loadavg.h>
#endif

#if defined(HAVE_GETLOADAVG)
#ifndef VMSTAT_LOAD_AVERAGE
#define VMSTAT_LOAD_AVERAGE
VALUE vmstat_load_average(VALUE self) {
  VALUE load = Qnil;
  double loadavg[AVGCOUNT];

  getloadavg(&loadavg[0], AVGCOUNT);

  load = rb_funcall(rb_path2class("Vmstat::LoadAverage"),
         rb_intern("new"), 3, rb_float_new(loadavg[0]),
                              rb_float_new(loadavg[1]),
                              rb_float_new(loadavg[2]));

  return load;
}
#endif
#endif
