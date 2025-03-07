# typed: true
# frozen_string_literal: true

class CreateDocuments < ActiveRecord::Migration[7.0]
  def change
    create_table :documents do |t|
      t.timestamps
    end
  end
end
