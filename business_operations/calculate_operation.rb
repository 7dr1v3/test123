class CalculateOperation
  Result = Struct.new(:operation, :positions)

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def call(positions)
    loyalty_program = user.loyalty_program

    # prepare_positions возвращает новый объект массива и новые объекты позиций, чтобы входные параметры не мутировать.
    positions = prepare_positions(positions)

    positions.map! do |position|
      calculate_loyalty(position, loyalty_program)
    end

    cashback = positions.map { |o| o[:cashback] }.sum
    discount = positions.map { |o| o[:discount] }.sum
    full_price = positions.map { |o| o[:full_price] }.sum
    result_price = positions.map { |o| o[:result_price] }.sum
    allowed_write_off = positions.map { |o| o[:allowed_write_off] }.sum

    operation = Operation.create(
      user_id: user.id,
      # Хранить нужно максимальный кешбэк без учёта бонусов, иначе мы не сможем делать перерасчёт кешбэка
      # при изменении write_off на этапе submit. Например если у клиента достаточно бонусов для полной оплаты то
      # результирующий кешбэка превращается в 0.
      # Соответственно значение write_off будет 0, чтобы не нарушать логику кешбэка.
      # А check_summ это полная стоимость с учётами скидок.
      cashback: cashback,
      cashback_percent: cashback / result_price,
      discount: discount,
      discount_percent: discount / full_price,
      done: false,
      allowed_write_off: allowed_write_off,
      write_off: 0,
      check_summ: result_price,
    )

    Result.new(operation, positions)
  end

  private

  def prepare_positions(positions)
    ids = positions.map { |o| o["id"] }
    products = Product.where(id: ids).all.to_h { |o| [o.id, o] }

    positions.map do |position|
      product = products[position["id"]]
      loyalty_rule = product ? product.loyalty_rule : LoyaltyRule::Default.new
      position.merge(product:, loyalty_rule:)
    end
  end

  def calculate_loyalty(position, loyalty_program)
    full_price = BigDecimal(position["price"]) * position["quantity"].to_i

    # Так как кешбэк зависит от списания бонусов, а в operation храним агрегированные значения,
    # то у нас принципиально не может быть товара для которого есть кешбэк,
    # но нету возможностии оплаты _полной_ стоимости бонусами.
    #
    # сумма всех position[:allowed_write_off] это сумма стоимостей товаров для которых нет запрета на loyalty 
    # если оплата бонусами максимальная то кешбэк = 0, если оплата бонусами = 0 то кешбэк будет максимальным,
    # обратная линейная зависимость. 

    if position[:loyalty_rule].allow_loyalty?
      discount_percent = BigDecimal(position[:loyalty_rule].discount) / 100
      cashback_percent = BigDecimal(position[:loyalty_rule].cashback) / 100

      # В задании не указано как складывать скидки, выбрал вариант при котором 0.75 и 0.5 дают 0.875
      discount_percent += (1 - discount_percent) * (BigDecimal(loyalty_program.discount) / 100)
      cashback_percent += (1 - cashback_percent) * (BigDecimal(loyalty_program.cashback) / 100)
    else
      discount_percent = BigDecimal(0)
      cashback_percent = BigDecimal(0)
    end

    discount = full_price * discount_percent
    result_price = full_price - discount

    # максимальный кешбэк без учёта списания бонусов
    cashback = result_price * cashback_percent

    position.merge!(discount_percent:, discount:, cashback_percent:, cashback:, full_price:, result_price:)

    position[:allowed_write_off] = position[:loyalty_rule].allow_loyalty? ? result_price : BigDecimal(0)

    position
  end
end
