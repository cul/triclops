class AddLimitedAndFeaturedSizesAndHasViewLimitationToResources < ActiveRecord::Migration[7.1]
  def change
    add_column :resources, :limited_width, :integer
    add_column :resources, :limited_height, :integer
    add_column :resources, :featured_width, :integer
    add_column :resources, :featured_height, :integer
    add_column :resources, :has_view_limitation, :boolean, null: false, default: true
  end
end
