# frozen_string_literal: true

class AddLockVersionToInvoices < ActiveRecord::Migration[7.2]
  def change
    # Enables ActiveRecord optimistic locking on Invoice updates.
    add_column :invoices, :lock_version, :integer, null: false, default: 0
  end
end
