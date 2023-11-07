class CreateResources < ActiveRecord::Migration[7.0]
  def change
    create_table :resources do |t|
      t.string :identifier
      t.text :source_uri
      t.integer :status, null: false, default: 0, index: true
      t.text  :error_message
      t.string :featured_region
      t.string :pcdm_type
      t.integer :width
      t.integer :height

      t.timestamps
      t.datetime :accessed_at, default: nil
    end

    add_index :resources, :identifier, unique: true
  end
end
