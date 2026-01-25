# example of object oriented in ruby
module Transfeable
  def transfer(amount, target_account)
    if balance >= amount
      withdraw(amount)
      target_account.deposit(amount)
      puts "Transfer successfull! Sent $#{amount} to #{target_account.owner}."
    else
      puts 'Transfer failed: Insufficient funds.'
    end
  end
end

class FinancialEntity
  attr_accessor :balance
  attr_reader :owner

  def initialize(owner, balance)
    @owner = owner
    @balance = balance
  end

  def deposit(amount)
    @balance += amount
  end

  def withdraw(amount)
    @balance -= amount
  end
end

class BankAccount < FinancialEntity
  include Transfeable

  def display_info
    "Bank Account [#{owner}]: $#{balance}"
  end
end

class DigitalWallet < FinancialEntity
  include Transfeable

  def pay_with_qr(amount)
    puts 'Scanning QR Code...'
    withdraw(amount)
  end
end

savings = BankAccount.new('Alice', 1000)
venmo = DigitalWallet.new('Bob', 50)

puts savings.display_info

savings.transfer(200, venmo)

puts "Alice's new balance: $#{savings.balance}"
puts "Bob's new balance: $#{venmo.balance}"
