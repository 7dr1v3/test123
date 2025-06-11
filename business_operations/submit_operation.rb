# frozen_string_literal: true

class SubmitOperation
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def call(operation_id, write_off)
    write_off = BigDecimal(write_off)

    DB.transaction do
      operation = user.operations_dataset.where(done: false).with_pk!(operation_id)

      # кешбек при write_off = 0
      max_cashback = operation.cashback

      # полная стоимость с учётом скидок
      result_price = operation.check_summ

      new_cashback = max_cashback * (1 - (write_off / operation.allowed_write_off))
      new_cashback_percent = new_cashback / result_price
      new_check_summ = result_price - write_off

      result = Operation.where(id: operation.id, done: false).update(
        done: true,
        cashback: new_cashback,
        cashback_percent: new_cashback_percent,
        check_summ: new_check_summ,
        write_off: write_off,
      )

      raise Sequel::Rollback if result != 1

      result = User.where(id: user.id).returning(:bonus).update(bonus: Sequel.lit("bonus - ?", write_off))
      raise Sequel::Rollback if result.first[:bonus] < 0

      User.where(id: user.id).update(bonus: Sequel.lit("bonus + ?", new_cashback))

      operation.reload
    end
  end
end
