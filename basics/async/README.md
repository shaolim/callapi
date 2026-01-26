# Basic Async

`async` is a Ruby library that provides asynchronous programming capabilities using fibers and a fiber scheduler. It allows you to write non-blocking, concurrent code.

A fiber is more comparable to a goroutine.

## Key Components

- The Reactor: The engine that manages all tasks and monitors I/0 events.
- Tasks: Units of work that run inside the reactor.
- Barriers/Semaphres: Tools to control how many tasks run at onece or wait for group to finish.
