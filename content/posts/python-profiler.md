---
title: "Python Profiler"
date: 2022-04-02T22:22:56+02:00
description: Learn how to profile a Python program by writing your own profiler.
draft: false
---

Profiling a program allows to detect bottlenecks to optimize either memory or speed of this one. Profiling is achieved in different ways depending the language but Python allows to very easily provide a profiler.

In this article we will quickly see the features of the default profiler provided by Python then we will explore the world of writing it's own profiler.

## Python `profile` and `cProfile` modules

Python provides two implementations of profilers: `profile` and `cProfile`. However it's recommended to use `cPython` because, as the name suggests, it's a C implementation and therefore has less overhead, leading to better results.

Python approach of profiling is the following: they collect the number of calls to each functions and accumulate the time spent in each of them. The profiler then print for each function:
- the number of calls
- the total time spent in it (excluding calls to sub-functions)
- the average time spent in it (per call, excluding calls to sub-functions)
- the total time spent in it (including calls to sub-functions)
- the average time spent in it (per call, including calls to sub-functions)

[see the documentation](https://docs.python.org/3/library/profile.html#instant-user-s-manual)

Calling such profiler is really simple and can also be done using a CLI:
```python
import cProfile
import re
cProfile.run('re.compile("foo|bar")')
```

The default profilers however does not allow for more precise analysis of function calls. Due to these limitations, you could be tempted to write your own profiler. 

## Writing our own profiler

In this section we'll discover how to write our own profiler for Python.

> For simplicity reasons I'll write the profiler using Python code instead of using a C-extension but writing a profiler using C language will give you much better results by reducing the overhead of profiler's code execution.

Python allows you to provide a profiling function that will be called when entering and exiting function frames. You can provide such function through the [sys.setprofile](https://docs.python.org/3/library/sys.html#sys.setprofile) function.

According to the documentation, the profiling function will receive 3 paramters: *frame*, *event* and *arg*. The *event* parameter is a string that can take the following values:
- `'call'`
- `'return'`
- `'c_call'`
- `'c_return'`
- `'c_exception'`

And *arg* parameter depends on the event type:
- for `'call'` *arg* is `None`
- for `'return'` *arg* is the value that will be returned
- for `'c_call'` *arg* is the C function object
- for `'c_return'` *arg* is the C function object
- for `'c_exception'` *arg* is the C function object

### Follow function calls

Let's create a simple profiler that will catch all these events and display the argument. 
```python
import sys
import time


def profile_call(frame, arg):
    print("CALL")


def profile_return(frame, arg):
    print("RETURN", arg)


def profile_c_call(frame, arg):
    print("C_CALL", arg)


def profile_c_return(frame, arg):
    print("C_RETURN", arg)


def profile_c_exception(frame, arg):
    print("C_EXCEPTION", arg)


def profiler(frame, event, arg):
    profilers = {
        "call": profile_call,
        "return": profile_return,
        "c_call": profile_c_call,
        "c_return": profile_c_return,
        "c_exception": profile_c_exception,
    }
    profilers[event](frame, arg)


sys.setprofile(profiler)

def a_python_func():
    time.time()
    try:
        with open("file2", "r"):
            pass
    except:
        pass
    return 12

a_python_func()
```

When we run the above script, we get the following output:

```
CALL
C_CALL <built-in function time>
C_RETURN <built-in function time>
C_CALL <built-in function open>
C_EXCEPTION <built-in function open>
RETURN 12
RETURN None
```

Let's see if we could have expected that. The profiling starts after the call to [sys.setprofile](https://docs.python.org/3/library/sys.html#sys.setprofile).
1. We call `a_python_func` which is a Python function, it then triggers a `'call'` event
2. We call [time.time](https://docs.python.org/fr/3/library/time.html#time.time) which is a built-in C function, it then triggers a `'c_call'` event
3. The [time.time](https://docs.python.org/fr/3/library/time.html#time.time) function returns, a `'c_return'` event is dispatched
4. We call [open](https://docs.python.org/fr/3/library/functions.html#open) function which is a built-in C function, so it triggers a `'c_call'` event
5. Because we try to read a file that doesn't exist, an exception is triggered by [open](https://docs.python.org/fr/3/library/functions.html#open), so `'c_exception'` is dispatched
6. We return the value `12` from the Python function, so the `'return'` event is dispatched
7. Finally, (I wasn't expecting this one), the script exits and then dispatch a `'return'` event

We achieved to follow the execution of the Python script but we didn't achieve to retrieve the name of the function that were called. Let's try to modify our script a bit.

### Retrieve function name

For C functions, it's really easy. They have the `__name__` attribute that contains the function name, so `arg.__name__` should return the C function name.

For Python function however, we saw that the *arg* value for `'call'` event is `None` so we will need to find it elsewhere.

We would like to find out which attributes the *frame* parameter has. I wasn't able to find this information in the Python documentation so I decided to put a breakpoint on the `print("CALL")` line but unfortunately the debugger doesn't get triggered. However, raising an exception in the `profile_call` function triggers the debugger so I'm able to inspect the *frame* object. The most important attributes for us right now is `f_code` which has the `co_name` attribute.

Let's update our script:
```python
def profile_call(frame, arg):
    print("CALL", frame.f_code.co_name)


def profile_return(frame, arg):
    print("RETURN", arg)


def profile_c_call(frame, arg):
    print("C_CALL", arg.__name__)


def profile_c_return(frame, arg):
    print("C_RETURN", arg.__name__)


def profile_c_exception(frame, arg):
    print("C_EXCEPTION", arg.__name__)
```

Now, running the script displays:
```
CALL a_python_func
C_CALL time
C_RETURN time
C_CALL open
C_EXCEPTION open
RETURN 12
RETURN None
```

### Writing our results to a file

Output to the stdout is not ideal so let's change a bit our script to output to a file. First, we'll create a class to wrap all of our functions:

```python
class Profiler:
    def __init__(self):
        self._frames_stack = []
    def profile_call(self, frame, arg):
        print("CALL", frame.f_code.co_name)

    def profile_return(self, frame, arg):
        print("RETURN", frame.f_code.co_name)

    def profile_c_call(self, frame, arg):
        print("C_CALL", arg.__name__)

    def profile_c_return(self, frame, arg):
        print("C_RETURN", arg.__name__)

    def profile_c_exception(self, frame, arg):
        print("C_EXCEPTION", arg.__name__)

    profilers = {
        "call": profile_call,
        "return": profile_return,
        "c_call": profile_c_call,
        "c_return": profile_c_return,
        "c_exception": profile_c_exception,
    }

    def profiler(self, frame, event, arg):
        self.profilers[event](self, frame, arg)


sys.setprofile(Profiler().profiler)
```

On let's now add a `profile` method that will open our file and start the profiling. In our other method we will then be able to write to the file instead of using [print](https://docs.python.org/3/library/functions.html#print):
```python
class Profiler:
    def __init__(self) -> None:
        self._file = None

    def profile_call(self, frame, arg):
        self._file.write(f"CALL {frame.f_code.co_name}\n")

    def profile_return(self, frame, arg):
        self._file.write(f"RETURN {frame.f_code.co_name}\n")

    def profile_c_call(self, frame, arg):
        self._file.write(f"C_CALL {arg.__name__}\n")

    def profile_c_return(self, frame, arg):
        self._file.write(f"C_RETURN {arg.__name__}\n")

    def profile_c_exception(self, frame, arg):
        self._file.write(f"C_EXCEPTION {arg.__name__}\n")

    profilers = {
        "call": profile_call,
        "return": profile_return,
        "c_call": profile_c_call,
        "c_return": profile_c_return,
        "c_exception": profile_c_exception,
    }

    def profiler(self, frame, event, arg):
        self.profilers[event](self, frame, arg)

    def profile(self, func):
        with open("events.txt", "w") as file:
            self._file = file
            sys.setprofile(self.profiler)
            try:
                func()
            finally:
                sys.setprofile(None)
```

Now, running `Profiler().profile(a_python_func)` outputs to a file `events.txt`:
```
CALL a_python_func
C_CALL time
C_RETURN time
C_CALL open
C_EXCEPTION open
RETURN a_python_func
C_CALL setprofile
```

> Note: We have captured a call to `setprofile` when calling `sys.setprofile(None)`

Let's associate timings with our profiling logs. To start, let's log time on each log line:
```python
class Profiler:
    
    ...

    def _log_time(self):
        self._file.write(f"{time.process_time()} ")

    def profile_call(self, frame, arg):
        self._log_time()
        self._file.write(f"CALL {frame.f_code.co_name}\n")

    def profile_return(self, frame, arg):
        self._log_time()
        self._file.write(f"RETURN {frame.f_code.co_name}\n")

    def profile_c_call(self, frame, arg):
        self._log_time()
        self._file.write(f"C_CALL {arg.__name__}\n")

    def profile_c_return(self, frame, arg):
        self._log_time()
        self._file.write(f"C_RETURN {arg.__name__}\n")

    def profile_c_exception(self, frame, arg):
        self._log_time()
        self._file.write(f"C_EXCEPTION {arg.__name__}\n")
    
    ...
```

Which outputs:
```
0.078125 CALL a_python_func
0.078125 C_CALL time
0.078125 C_RETURN time
0.078125 C_CALL open
0.078125 C_EXCEPTION open
0.078125 RETURN a_python_func
0.078125 C_CALL setprofile
```

We observe two problems:
1. The time is the same of all calls
2. The time do not start at 0

The first problem is due to our calls not taking enough time, [time.process_time](https://docs.python.org/fr/3/library/time.html#time.process_time) resolution is too low. This problem should be solved later when calling functions requiring more computational power.
> Note: using [time.sleep](https://docs.python.org/fr/3/library/time.html#time.sleep) here won't help us because [time.process_time](https://docs.python.org/fr/3/library/time.html#time.process_time) doesn't include sleep time.

The second problem can however be solved by retaining the time of the first event of type `'call'` or `'c_call'` and substracting later time by this initial time:
```python
class Profiler:
    def __init__(self) -> None:
        self._file = None
        self._initial_time = None

    def _log_time(self):
        if self._initial_time is None:
            self._initial_time = time.process_time()
        self._file.write(f"{time.process_time() - self._initial_time} ")

    ...
```

Which now gives:

```
0.0 CALL a_python_func
0.0 C_CALL time
0.0 C_RETURN time
0.0 C_CALL open
0.0 C_EXCEPTION open
0.0 RETURN a_python_func
0.0 C_CALL setprofile
```

Much better.

Now let's test our profiler against function with higher computational requirements.
```python
def fib(n):
    if n == 0:
        return 0
    prev = 0
    curr = 1
    for _ in range(1, n):
        prev, curr = curr, prev + curr
    return curr


def dump_to_file():
    with open("out.txt", "w") as file:
        file.write("A" * 500_000)


def b_python_func():
    fib(50_000)
    dump_to_file()
    return 12

Profiler().profile(b_python_func)
```

Which gives use:

```
0.0 CALL b_python_func
0.0 CALL fib
0.015625 RETURN fib
0.015625 CALL dump_to_file
0.015625 C_CALL open
0.015625 CALL getpreferredencoding
0.015625 C_CALL _getdefaultlocale
0.015625 C_RETURN _getdefaultlocale
0.015625 RETURN getpreferredencoding
0.015625 CALL __init__
0.015625 RETURN __init__
0.015625 C_RETURN open
0.015625 C_CALL write
0.015625 CALL encode
0.015625 C_CALL charmap_encode
0.03125 C_RETURN charmap_encode
0.03125 RETURN encode
0.03125 C_RETURN write
0.03125 C_CALL __exit__
0.03125 C_RETURN __exit__
0.03125 RETURN dump_to_file
0.03125 RETURN b_python_func
0.03125 C_CALL setprofile
```

### Visualization of our profiling

Google Chrome provides a great visualization tool for profiling and we could take advantage of it to view our profiling. This tool can be found at address [chrome://tracing](chrome://tracing) in Google Chrome browser. The specification of the file format can be found [here](https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview#).

We see that we can provide an array of JSON object with the following properties:
- `pid`: process id
- `tid`: thread id
- `name`: the name of the function
- `ts`: timestamp of the event
- `ph`: event type (`B` for enter and `E` for exit)

We already have the name, the type and the timestamp. For others, because we only handle 1 process and 1 thread we can put fixed values. Let's write a JSON to our file:
```python
class Profiler:
    
    ...

    def __trace_enter(self, func_name):
        add_comma = True
        if self._initial_time is None:
            self._initial_time = time.process_time()
            add_comma = False
        trace = {
            "pid": 1,
            "tid": 1,
            "ph": "B",
            "ts": time.process_time() - self._initial_time,
            "name": func_name
        }
        if add_comma:
            self._file.write(",\n")
        self._file.write(f"{json.dumps(trace)}")

    def __trace_exit(self, func_name):
        trace = {
            "pid": 1,
            "tid": 1,
            "ph": "E",
            "ts": time.process_time() - self._initial_time,
            "name": func_name
        }
        self._file.write(f",\n{json.dumps(trace)}")

    def profile_call(self, frame, arg):
        self.__trace_enter(frame.f_code.co_name)

    def profile_return(self, frame, arg):
        self.__trace_exit(frame.f_code.co_name)

    def profile_c_call(self, frame, arg):
        self.__trace_enter(arg.__name__)

    def profile_c_return(self, frame, arg):
        self.__trace_exit(arg.__name__)

    def profile_c_exception(self, frame, arg):
        self.__trace_exit(arg.__name__)
    
    ...
```

Which gives us:
```json
[
    {"pid": 1, "tid": 1, "ph": "B", "ts": 0.0, "name": "b_python_func"},
    {"pid": 1, "tid": 1, "ph": "B", "ts": 0.0, "name": "fib"},
    {"pid": 1, "tid": 1, "ph": "E", "ts": 0.015625, "name": "fib"},
    {"pid": 1, "tid": 1, "ph": "B", "ts": 0.015625, "name": "dump_to_file"},
    {"pid": 1, "tid": 1, "ph": "B", "ts": 0.015625, "name": "open"},
    {"pid": 1, "tid": 1, "ph": "B", "ts": 0.015625, "name": "getpreferredencoding"},
    {"pid": 1, "tid": 1, "ph": "B", "ts": 0.015625, "name": "_getdefaultlocale"},
    {"pid": 1, "tid": 1, "ph": "E", "ts": 0.015625, "name": "_getdefaultlocale"},
    {"pid": 1, "tid": 1, "ph": "E", "ts": 0.015625, "name": "getpreferredencoding"},
    {"pid": 1, "tid": 1, "ph": "B", "ts": 0.015625, "name": "__init__"},
    {"pid": 1, "tid": 1, "ph": "E", "ts": 0.015625, "name": "__init__"},
    {"pid": 1, "tid": 1, "ph": "E", "ts": 0.015625, "name": "open"},
    {"pid": 1, "tid": 1, "ph": "B", "ts": 0.015625, "name": "write"},
    {"pid": 1, "tid": 1, "ph": "B", "ts": 0.015625, "name": "encode"},
    {"pid": 1, "tid": 1, "ph": "B", "ts": 0.015625, "name": "charmap_encode"},
    {"pid": 1, "tid": 1, "ph": "E", "ts": 0.015625, "name": "charmap_encode"},
    {"pid": 1, "tid": 1, "ph": "E", "ts": 0.015625, "name": "encode"},
    {"pid": 1, "tid": 1, "ph": "E", "ts": 0.03125, "name": "write"},
    {"pid": 1, "tid": 1, "ph": "B", "ts": 0.03125, "name": "__exit__"},
    {"pid": 1, "tid": 1, "ph": "E", "ts": 0.03125, "name": "__exit__"},
    {"pid": 1, "tid": 1, "ph": "E", "ts": 0.03125, "name": "dump_to_file"},
    {"pid": 1, "tid": 1, "ph": "E", "ts": 0.03125, "name": "b_python_func"},
    {"pid": 1, "tid": 1, "ph": "B", "ts": 0.03125, "name": "setprofile"}
]
```

Now, let's just open [chrome://tracing](chrome://tracing), load our file and see what happens:

![](/img/python-profiler/chrome-tracing.png)

We now have our stacktrace with timing associated to each calls.

### Conclusion

Creating it's own profiler isn't something easy but I discovered it to be easier than I thought in Python. Of course, the profiler we designed here is lacking a lof of fonctionalities.

Improvements could be following:
- Handling multiple processes
- Handling multiple threads
- Reducing profiler overhead