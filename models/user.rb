# frozen_string_literal: true

class User < Sequel::Model
  one_to_many :operations
  many_to_one :loyalty_program, key: :template_id
end
