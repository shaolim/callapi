# Async::Barrier (similar to waitgroup)
# Key methods:
# `barrier.async { block }` -> spawns a new task within the barrier
# `barrier.wait` -> blocks until all tasks in the barrier complete
# `barrier.stop` -> immediately stops all running task in the barrier
#
# Barrier vs Task
# Use Barrier when:
# - You need to wait for multiple tasks to complete
# - You want to manage a group of related tasks together
# - You need easy cleanup/cancellation of multiple tasks
# User Task directly when:
# - You need more fine-grained control
# - You want to get return values from individual tasks
# - Tasks are independent and don't need coordination

require 'async'
require 'async/http/internet'
require 'async/semaphore'

Async do
  barrier = Async::Barrier.new
  barrier.async do
    loop do
      puts 'Working...'
      sleep 1
    end
  end

  sleep 3
  barrier.stop # stops the infinite loop
end

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

# You can control how many tasks run concurrently using a semaphore
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

# Common Patterns
## Fan-out, Fan-in
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

## timeout pattern
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
