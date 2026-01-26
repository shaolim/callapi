require 'async'
require 'async/http/internet'

# Basic
Async do
  puts 'Starting task'
  sleep 1
  puts 'Task complete'
end

# Async::Task
# Represents an asynchronous operation:
Async do |task|
  # spawn concurrent task
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

# Async::Barrier (this is similar to WaitGroups in golang)
# Waits for multiple tasks to complete
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

# Async::HTTP::Internet (concurrent HTTP requests)
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
    # use task.wait if you want to wait for specific tasks individually
    response = task.wait
    puts response.read
  end
ensure # ensure is similar to `final` or `defer` in golang
  # `(&.)` operator is safe operator
  # Without (&.) - can raise error if internet is nil
  # similar to (?.) in kotlin
  internet&.close
end
