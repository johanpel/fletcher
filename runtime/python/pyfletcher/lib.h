/* Generated by Cython 0.28.5 */

#ifndef __PYX_HAVE__lib
#define __PYX_HAVE__lib


#ifndef __PYX_HAVE_API__lib

#ifndef __PYX_EXTERN_C
  #ifdef __cplusplus
    #define __PYX_EXTERN_C extern "C"
  #else
    #define __PYX_EXTERN_C extern
  #endif
#endif

#ifndef DL_IMPORT
  #define DL_IMPORT(_T) _T
#endif

__PYX_EXTERN_C int pyfletcher_is_usercore(PyObject *);
__PYX_EXTERN_C PyObject *pyfletcher_wrap_usercore(std::shared_ptr< fletcher::UserCore>  const &);
__PYX_EXTERN_C std::shared_ptr< fletcher::UserCore>  pyfletcher_unwrap_usercore(PyObject *);
__PYX_EXTERN_C int pyfletcher_is_platform(PyObject *);
__PYX_EXTERN_C PyObject *pyfletcher_wrap_platform(std::shared_ptr< fletcher::Platform>  const &);
__PYX_EXTERN_C std::shared_ptr< fletcher::Platform>  pyfletcher_unwrap_platform(PyObject *);

#endif /* !__PYX_HAVE_API__lib */

/* WARNING: the interface of the module init function changed in CPython 3.5. */
/* It now returns a PyModuleDef instance instead of a PyModule instance. */

#if PY_MAJOR_VERSION < 3
PyMODINIT_FUNC initlib(void);
#else
PyMODINIT_FUNC PyInit_lib(void);
#endif

#endif /* !__PYX_HAVE__lib */
