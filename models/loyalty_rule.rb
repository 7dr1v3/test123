# frozen_string_literal: true

module LoyaltyRule
  class Default
    attr_reader :value

    def initialize(value = nil)
      @value = value
    end

    def allow_loyalty?
      true
    end

    def discount
      0
    end

    def cashback
      0
    end
  end

  class IncreasedCashback < Default
    def cashback
      value.to_i
    end
  end

  class Discount < Default
    def discount
      value.to_i
    end
  end

  class NoLoyalty < Default
    def allow_loyalty?
      false
    end
  end
end