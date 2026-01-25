# yield
def logger
  yield
end

logger { puts 'hello from the block' }
# => hello from the block

logger do
  p [1, 2, 3]
end
# => [1, 2, 3]

def love_language
  yield('Ruby')
  yield('Golang')
end

love_language { |lang| puts "I love #{lang}" }
# I love Ruby
# I love Golang

@transactions = [10, -15, 25, 30, -24, -70, 999]
def transactions_statement(&)
  @transactions.each(&)
end

transactions_statement do |transaction|
  p format('%0.2f', transaction)
end
# => "10.00"
# => "-15.00"
# => "25.00"
# => "30.00"
# => "-24.00"
# => "-70.00"
# => "999.00"

## if you want to gather the value returned from the block,
# you can just assign it to a variable or collect it in a data structure
def transactions_statement2
  formatted_transactions = []
  @transactions.each do |transaction| # rubocop:disable Style/MapIntoArray
    formatted_transactions << yield(transaction)
  end

  p formatted_transactions
end

transactions_statement2 do |transaction|
  format('%0.2f', transaction)
end
# => ["10.00", "-15.00", "25.00", "30.00", "-24.00", "-70.00", "999.00"]

def awesome_method
  hash = { a: 'apple', b: 'banana', c: 'cookie' }
  hash.each do |key, value| # rubocop:disable Style/ExplicitBlockArgument
    yield key, value
  end
end

awesome_method { |key, value| puts "#{key}: #{value}" }
# => a: apple
# => b: banana
# => c: cookie

# Block control
# You can use `block_given?` as conditional check inside method to see if a
# block was included by the caller. If so, `block_given?` returns `true`, otherwise
# it returns `false`
def maybe_block
  puts 'block party' if block_given?
  puts 'executed regardless'
end

maybe_block
# => executed regardless

maybe_block {} # rubocop:disable Lint/EmptyBlock
# => block party
# => executed regardless

# capturing blocks
# Ruby allows us to capture blocks in a method definition as a special argument using `&`
def cool_method(&my_block)
  my_block.call
end

cool_method { puts 'cool' }
