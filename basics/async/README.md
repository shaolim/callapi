# Ruby Async Programming Guide

`async` is a Ruby library that provides asynchronous programming capabilities using fibers and a fiber scheduler. It allows you to write non-blocking, concurrent code.

A fiber is more comparable to a goroutine in Go.

## Key Components

- **The Reactor**: The engine that manages all tasks and monitors I/O events.
- **Tasks**: Units of work that run inside the reactor.
- **Barriers**: Tools to wait for a group of tasks to finish (similar to WaitGroups in Go).
- **Semaphores**: Control how many tasks run concurrently.

## Basic Usage

### Simple Async Block

```ruby
require 'async'

Async do
  puts 'Starting task'
  sleep 1
  puts 'Task complete'
end
```

See: [basic.ruby:5-9](basic.ruby:5-9)

## Async::Task

Represents an asynchronous operation. You can spawn concurrent tasks within a parent task:

```ruby
Async do |task|
  # Spawn concurrent task
  task.async do
    puts 'Task 1'
    sleep 1
    puts 'Task 1 done'
  end

  task.async do
    puts 'Task 2'
    sleep 1
    puts 'Task 2 done'
  end
end
```

See: [basic.ruby:11-26](basic.ruby:11-26)

### Getting Return Values from Tasks

```ruby
Async do |task|
  tasks = [
    task.async { some_operation() },
    task.async { another_operation() }
  ]

  # Wait for specific tasks individually
  results = tasks.map { |t| t.wait }
end
```

See: [basic.ruby:48-63](basic.ruby:48-63)

## Async::Barrier

Similar to WaitGroups in Go. A barrier manages a group of related tasks and waits for them all to complete.

### Key Methods

- `barrier.async { block }` - Spawns a new task within the barrier
- `barrier.wait` - Blocks until all tasks in the barrier complete
- `barrier.stop` - Immediately stops all running tasks in the barrier

See: [barrier.ruby:1-15](barrier.ruby:1-15)

### Basic Barrier Usage

```ruby
Async do
  barrier = Async::Barrier.new

  barrier.async do
    sleep 1
    puts 'First task'
  end

  barrier.async do
    sleep 2
    puts 'Second task'
  end

  barrier.wait # Waits for all tasks
  puts 'All done!'
end
```

See: [basic.ruby:28-45](basic.ruby:28-45)

### Stopping Tasks with Barrier

```ruby
Async do
  barrier = Async::Barrier.new

  barrier.async do
    loop do
      puts 'Working...'
      sleep 1
    end
  end

  sleep 3
  barrier.stop # Stops the infinite loop
end
```

See: [barrier.ruby:21-32](barrier.ruby:21-32)

### Barrier vs Task

**Use Barrier when:**
- You need to wait for multiple tasks to complete
- You want to manage a group of related tasks together
- You need easy cleanup/cancellation of multiple tasks

**Use Task directly when:**
- You need more fine-grained control
- You want to get return values from individual tasks
- Tasks are independent and don't need coordination

See: [barrier.ruby:7-15](barrier.ruby:7-15)

## Async::Semaphore

Controls how many tasks run concurrently:

```ruby
require 'async/semaphore'

Async do
  barrier = Async::Barrier.new
  semaphore = Async::Semaphore.new(2) # Max 2 concurrent tasks

  10.times do |i|
    barrier.async do
      semaphore.acquire do
        puts "Starting task #{i}"
        sleep 1
        puts "Finished task #{i}"
      end
    end
  end

  barrier.wait
end
```

See: [barrier.ruby:65-81](barrier.ruby:65-81)

## HTTP Requests with Async::HTTP::Internet

Make concurrent HTTP requests efficiently:

```ruby
require 'async/http/internet'

Async do |task|
  internet = Async::HTTP::Internet.new

  # Spawn concurrent HTTP requests
  tasks = [
    task.async { internet.get('https://example.com') },
    task.async { internet.get('https://example.org') },
    task.async { internet.get('https://example.net') }
  ]

  # Wait for all responses and read them
  tasks.each do |task|
    response = task.wait
    puts response.read
  end
ensure
  internet&.close
end
```

See: [basic.ruby:47-69](basic.ruby:47-69)

### Fetching Multiple URLs with Barrier

```ruby
def fetch_multiple_urls(urls)
  Async do
    barrier = Async::Barrier.new
    internet = Async::HTTP::Internet.new
    results = {}

    urls.each do |url|
      barrier.async do
        response = internet.get(url)
        results[url] = response.read
        puts "Fetched: #{url}"
      end
    end

    barrier.wait
    results
  ensure
    internet&.close
  end
end

urls = [
  'https://api.github.com/users/github',
  'https://api.github.com/users/rails',
  'https://api.github.com/users/ruby'
]

results = fetch_multiple_urls(urls).wait
puts "Fetched #{results.size} URLs"
```

See: [barrier.ruby:34-63](barrier.ruby:34-63)

## Common Patterns

### Fan-out, Fan-in Pattern

Process items in parallel and collect results:

```ruby
def parallel_map(items, &block)
  Async do
    barrier = Async::Barrier.new
    results = []

    items.each do |item|
      barrier.async do
        result = block.call(item)
        results << result
      end
    end

    barrier.wait
    results
  end
end

numbers = [1, 2, 3, 4, 5]
squared = parallel_map(numbers) { |n| n * n }.wait
puts squared.inspect # May not be in order since we use <<
```

See: [barrier.ruby:83-104](barrier.ruby:83-104)

### Timeout Pattern

Set timeouts for long-running tasks:

```ruby
Async do |task|
  barrier = Async::Barrier.new

  barrier.async do
    sleep 5 # Long-running task
    puts 'This might timeout'
  end

  begin
    task.with_timeout(2) do
      barrier.wait
    end
  rescue Async::TimeoutError
    puts 'Timed out!'
    barrier.stop
  end
end
```

See: [barrier.ruby:106-123](barrier.ruby:106-123)

## Ruby-Specific Syntax Notes

### ensure Block

The `ensure` block is similar to `finally` in other languages or `defer` in Go. It always executes, even if an exception is raised:

```ruby
begin
  # code that might raise
ensure
  # cleanup code - always runs
  internet&.close
end
```

See: [basic.ruby:64](basic.ruby:64)

### Safe Navigation Operator (&.)

The `&.` operator is Ruby's safe navigation operator (similar to `?.` in Kotlin or optional chaining in JavaScript). It only calls the method if the object is not nil:

```ruby
# Without &. - can raise error if internet is nil
internet.close

# With &. - safe, does nothing if internet is nil
internet&.close
```

See: [basic.ruby:65-68](basic.ruby:65-68)

## Summary

The async library provides powerful tools for concurrent programming in Ruby:

1. Use `Async do |task|` to create an async context
2. Use `task.async` to spawn concurrent tasks with fine-grained control
3. Use `Async::Barrier` to manage groups of related tasks
4. Use `Async::Semaphore` to limit concurrency
5. Use `Async::HTTP::Internet` for concurrent HTTP requests
6. Common patterns: fan-out/fan-in, timeouts, and controlled concurrency

For more examples, see:
- [basic.ruby](basic.ruby) - Basic async concepts and HTTP requests
- [barrier.ruby](barrier.ruby) - Advanced barrier usage and patterns
