# frozen_string_literal: true
class Product < Sequel::Model
  LOYALTY_RULES = {
    nil => LoyaltyRule::Default, # type может быть nil, в базе нет ограничения
    "default" => LoyaltyRule::Default,
    "increased_cashback" => LoyaltyRule::IncreasedCashback,
    "discount" => LoyaltyRule::Discount,
    "noloyalty" => LoyaltyRule::NoLoyalty,
  }

  # id продуктов не случайны
  unrestrict_primary_key

  def loyalty_rule
    @loyalty_rule ||= LOYALTY_RULES[type].new(value)
  end
end

