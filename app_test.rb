ENV["APP_ENV"] = "test"

require "./app.rb"
require "test/unit"
require "rack/test"

set :environment, :test

class AppTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_root_returns_ok
    get "/"

    assert last_response.ok?
    assert_equal last_response.body, "OK"
  end

  def test_operation_with_discount_loyalty_program
    loyalty_program = LoyaltyProgram.create(name: "Discount", discount: 10, cashback: 0)
    user = User.create(loyalty_program:, name: "TestName", bonus: 10_000)

    post "/operation", { user_id: user.id, positions: [
      {"id" => 1, "price" => 100, "quantity" => 5},
      {"id" => 2, "price" => 10, "quantity" => 5},
    ]}.to_json

    assert last_response.ok?

    result = JSON.parse(last_response.body)

    assert_equal result["user"]["id"], user.id
    assert_equal result["user"]["loyalty_program"]["id"], loyalty_program.id
    assert_equal result["check_summ"], 495
    assert_equal result["bonuses"]["allowed_write_off"], 495
    assert_equal result["bonuses"]["cashback_percent"], 0
    assert_equal result["bonuses"]["cashback"], 0
    assert_equal result["discount"]["discount"], 55
    assert_equal result["discount"]["discount_percent"], 10
    assert_equal result["positions"].size, 2

    post "/submit", { user: {id: user.id}, operation_id: result["operation_id"], write_off: 95 }.to_json

    assert last_response.ok?

    result = JSON.parse(last_response.body)

    assert_equal result["operation"]["user_id"], user.id
    assert_equal result["operation"]["discount"], 55
    assert_equal result["operation"]["discount_percent"], 10
    assert_equal result["operation"]["write_off"], 95
    assert_equal result["operation"]["check_summ"], 400
    assert_equal result["operation"]["cashback_percent"], 0
    assert_equal result["operation"]["cashback"], 0
  end

  def test_operation_with_cashback_loyalty_program
    loyalty_program = LoyaltyProgram.create(name: "Cashback", discount: 0, cashback: 10)
    user = User.create(loyalty_program:, name: "TestName", bonus: 10_000)

    post "/operation", { user_id: user.id, positions: [
      {"id" => 1, "price" => 100, "quantity" => 5},
      {"id" => 2, "price" => 10, "quantity" => 5},
    ]}.to_json

    assert last_response.ok?

    result = JSON.parse(last_response.body)

    assert_equal result["check_summ"], 550
    assert_equal result["bonuses"]["allowed_write_off"], 550
    assert_equal result["bonuses"]["cashback_percent"], 10
    assert_equal result["bonuses"]["cashback"], 55
    assert_equal result["discount"]["discount"], 0
    assert_equal result["discount"]["discount_percent"], 0
    assert_equal result["positions"].size, 2

    post "/submit", { user: {id: user.id}, operation_id: result["operation_id"], write_off: 50 }.to_json

    assert last_response.ok?

    result = JSON.parse(last_response.body)

    assert_equal result["operation"]["user_id"], user.id
    assert_equal result["operation"]["discount"], 0
    assert_equal result["operation"]["discount_percent"], 0
    assert_equal result["operation"]["write_off"], 50
    assert_equal result["operation"]["check_summ"], 500
    assert_equal result["operation"]["cashback_percent"], 9.090909090909092
    assert_equal result["operation"]["cashback"], 50
  end

  def test_operation_with_loyalty_rules
    loyalty_program = LoyaltyProgram.create(name: "Empty", discount: 0, cashback: 0)
    user = User.create(loyalty_program:, name: "TestName", bonus: 10_000)

    Product.create(id: 1, name: "1", type: "default", value: nil)
    Product.create(id: 2, name: "2", type: "increased_cashback", value: 10)
    Product.create(id: 3, name: "3", type: "discount", value: 10)
    Product.create(id: 4, name: "4", type: "noloyalty", value: nil)
    Product.create(id: 5, name: "5", type: nil, value: nil)

    post "/operation", { user_id: user.id, positions: [
      {"id" => 1, "price" => 100, "quantity" => 10},
      {"id" => 2, "price" => 100, "quantity" => 10},
      {"id" => 3, "price" => 100, "quantity" => 10},
      {"id" => 4, "price" => 100, "quantity" => 10},
      {"id" => 5, "price" => 100, "quantity" => 10},
      {"id" => 6, "price" => 100, "quantity" => 10},
    ]}.to_json

    assert last_response.ok?

    result = JSON.parse(last_response.body)

    assert_equal result["check_summ"], 5900
    assert_equal result["bonuses"]["allowed_write_off"], 4900
    assert_equal result["bonuses"]["cashback"], 100
    assert_equal result["bonuses"]["cashback_percent"], 1.694915254237288 # 100.0 / 5900.0
    assert_equal result["discount"]["discount"], 100
    assert_equal result["discount"]["discount_percent"], 1.6666666666666667 # 100.0 / 6000.0

    post "/submit", { user: {id: user.id}, operation_id: result["operation_id"], write_off: 4900 }.to_json

    assert last_response.ok?

    result = JSON.parse(last_response.body)

    assert_equal result["operation"]["cashback"], 0
    assert_equal result["operation"]["cashback_percent"], 0
    assert_equal result["operation"]["discount"], 100
    assert_equal result["operation"]["discount_percent"], 1.6666666666666667
    assert_equal result["operation"]["write_off"], 4900
    assert_equal result["operation"]["check_summ"], 1000
  end
end

