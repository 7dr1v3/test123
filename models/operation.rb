# frozen_string_literal: true

class Operation < Sequel::Model
  many_to_one :user
end
