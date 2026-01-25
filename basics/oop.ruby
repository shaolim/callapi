# Object Oriented

class Robot
  def initialize(name)
    @name = name
  end

  def say_hello
    puts "Hello, I am #{@name}!"
  end
end

r1 = Robot.new('R2-D2')
r1.say_hello

## inheritance
class Animal
  def breathe
    puts 'Inhale... exhale...'
  end
end

class Cat < Animal
  def speak
    puts 'Meow!'
  end
end

my_cat = Cat.new
my_cat.breathe
my_cat.speak

## encapsulation
#
class BankAccount
  def deposit(amount)
    @balance = amount
    secure_log
  end

  private

  def secure_log
    puts 'Transaction recorded in encrypted vault.'
  end
end

account = BankAccount.new
account.deposit(100)

## Modules and Mixins
# Ruby does not allow a class to inherit from more than one parent.
# To solve this, we use Modules. These are groups of methods you can "drop in" (mix in) to any class.

module Flyable
  def fly
    puts "I'm taking off!"
  end
end

class Bird < Animal
  include Flyable
end

my_bird = Bird.new
my_bird.breathe
my_bird.fly
