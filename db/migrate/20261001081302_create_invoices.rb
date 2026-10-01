# frozen_string_literal: true

class CreateInvoices < ActiveRecord::Migration[7.2]
  def change
    create_table :invoices do |t|
      # Stored in pennies (integer cents), never as a float.
      t.integer :total, null: false

      t.timestamps
    end
  end
end
