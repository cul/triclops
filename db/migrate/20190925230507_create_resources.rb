class CreateResources < ActiveRecord::Migration[6.0]
  def change
    create_table :resources do |t|
      t.string :identifier
      t.string :featured_region
      t.text :location_uri
      t.integer :width
      t.integer :height

      t.timestamps
      t.datetime :accessed_at, null: true, default: nil
    end

    add_index :resources, :identifier, unique: true
  end
end
