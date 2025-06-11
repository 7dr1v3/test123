class LoyaltyProgram < Sequel::Model(:templates)
  one_to_many :users
end