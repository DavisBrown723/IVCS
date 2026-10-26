"""Serialize owned benchmarks and analysis; release the process-owned lease at exit."""
import atexit,ctypes,os,subprocess,sys
MUTEX_NAME=r"Local\IVCS_Combat_Timing"
_owned=None

def assert_benchmark_idle():
    global _owned
    if _owned is not None or os.name!='nt' or os.environ.get('IVCS_TIMING_DIAGNOSTIC_INTERFERENCE')=='1':
        return
    k=ctypes.WinDLL('kernel32',use_last_error=True)
    k.CreateMutexW.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_wchar_p]
    k.CreateMutexW.restype=ctypes.c_void_p
    k.WaitForSingleObject.argtypes=[ctypes.c_void_p,ctypes.c_uint32]
    k.ReleaseMutex.argtypes=[ctypes.c_void_p]
    k.CloseHandle.argtypes=[ctypes.c_void_p]
    handle=k.CreateMutexW(None,False,MUTEX_NAME)
    if not handle:raise OSError(ctypes.get_last_error(),'Cannot create timing lease')
    state=k.WaitForSingleObject(handle,0)
    if state not in (0,0x80):
        k.CloseHandle(handle)
        if state==258:raise RuntimeError('An IVCS benchmark or analysis owns the timing lease. Run captures and analysis sequentially.')
        raise OSError(ctypes.get_last_error(),'Cannot acquire timing lease')
    _owned=(k,handle)
    def release():
        k.ReleaseMutex(handle);k.CloseHandle(handle)
    atexit.register(release)

if __name__=='__main__':
    assert_benchmark_idle()
    if len(sys.argv)>1:sys.exit(subprocess.call(sys.argv[1:]))
