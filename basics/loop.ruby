# Loops
# it's an infinite loop that will keep going unless you specifically request for it to stop,
# using `break` command
i = 0
loop do
  puts "i is #{i}"
  i += 1
  break if i == 10
end

# while loop
j = 0
while i < 10
  puts "j is is #{j}"
  j += 1
end

# until loop
# until loop is the opposite of the `while` loop.
# A `while` loop continues for as long as the condition is true,
# whereas an until loop continues for as long as the condition is false.
h = 0
until h >= 10
  puts "h is #{h}"
  h += 1
end

# for loop
# a `for` loop is used to iterate through a collection of information such as an array or range.
for i in 0..5 # rubocop:disable Style/For
  puts "#{i} zombies incoming!"
end

# each
inclusive = (1..5) # inclusive range: 1, 2, 3, 4, 5
inclusive.each do |x|
  puts "x is #{x}"
end
exclusive = (1...5) # exclusive range: 1, 2, 3, 4
exclusive.each do |y|
  puts "y is #{y} "
end

# times loop
5.times do
  puts 'Hello, world!'
end

5.times do |number|
  puts "Alternative fact number #{number}"
end
