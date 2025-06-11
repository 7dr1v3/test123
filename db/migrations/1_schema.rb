# frozen_string_literal: true
Sequel.migration do
  change do
    create_table(:products, ignore_index_errors: true) do
      primary_key :id
      String :name, size: 255, null: false
      String :type, size: 255
      String :value, size: 255

      index [:id], name: :table_name_id_uindex, unique: true
    end

    create_table(:templates, ignore_index_errors: true) do
      primary_key :id
      String :name, size: 255, null: false
      Integer :discount, null: false
      Integer :cashback, null: false

      index [:id], name: :template_id_uindex, unique: true
    end

    create_table(:users, ignore_index_errors: true) do
      primary_key :id
      foreign_key :template_id, :templates, null: false
      String :name, size: 255, null: false
      BigDecimal :bonus

      index [:id], name: :user_id_uindex, unique: true
    end

    create_table(:operations, ignore_index_errors: true) do
      primary_key :id
      foreign_key :user_id, :users, null: false
      BigDecimal :cashback, null: false
      BigDecimal :cashback_percent, null: false
      BigDecimal :discount, null: false
      BigDecimal :discount_percent, null: false
      BigDecimal :write_off
      BigDecimal :check_summ, null: false
      TrueClass :done
      BigDecimal :allowed_write_off

      index [:id], name: :operation_id_uindex, unique: true
    end
  end
end
