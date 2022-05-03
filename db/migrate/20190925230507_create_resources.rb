class CreateResources < ActiveRecord::Migration[6.0]
  def change
    create_table :resources do |t|
      t.string :identifier # ideally, every record should have only one identifier
      t.string :secondary_identifier # this is for handling identifier migration scenarios
      t.string :featured_region
      t.text :location_uri
      t.integer :width
      t.integer :height

      t.timestamps
      t.datetime :accessed_at, null: true, default: nil
    end

    add_index :resources, :identifier, unique: true
    add_index :resources, :secondary_identifier, unique: true
  end
end
