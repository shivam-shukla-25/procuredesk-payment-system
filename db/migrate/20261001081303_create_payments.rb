# frozen_string_literal: true

class CreatePayments < ActiveRecord::Migration[7.2]
  def change
    create_table :payments do |t|
      t.references :invoice, null: false, foreign_key: true
      # Integer code for cash/check/charge — not a FK (no payment_methods table).
      t.integer :payment_method_id, null: false
      # Stored in pennies (integer cents), never as a float.
      t.integer :amount, null: false

      t.timestamps
    end

    add_index :payments, :payment_method_id
  end
end
