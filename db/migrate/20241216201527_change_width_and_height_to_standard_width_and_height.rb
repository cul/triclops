class ChangeWidthAndHeightToStandardWidthAndHeight < ActiveRecord::Migration[7.1]
  def change
    rename_column :resources, :width, :standard_width
    rename_column :resources, :height, :standard_height
  end
end
