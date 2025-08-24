require 'rails_helper'

RSpec.describe Resource, type: :model do
  let(:identifier) { 'test' }
  let(:rails_root_relative_path) { File.join('spec', 'fixtures', 'files', 'sample.jpg') }
  let(:source_file_path) { Rails.root.join(rails_root_relative_path).to_s }
  let(:source_uri) { 'railsroot:///' + rails_root_relative_path }
  let(:standard_width) { 1920 }
  let(:standard_height) { 3125 }
  let(:featured_region) { '320,616,1280,1280' }
  let(:instance) do
    described_class.new({
      identifier: identifier,
      source_uri: source_uri,
      standard_width: standard_width,
      standard_height: standard_height,
      featured_region: featured_region
    })
  end

  context "#iiif_info" do
    let(:id_url) { 'http://localhost:3000/iiif/2/' + identifier }
    let(:sizes) do
      [
        [157, 256],
        [315, 512],
        [629, 1024],
        [786, 1280]
      ]
    end
    let(:formats) { ['png', 'jpg'] }
    let(:qualities) { ['default', 'color'] }
    let(:tile_size) { 512 }
    let(:scale_factors) { [1, 2, 4, 8, 16] }
    it 'returns the expected hash' do
      expect(
        {
          '@context': 'http://iiif.io/api/image/2/context.json',
          '@id': id_url,
          'protocol': 'http://iiif.io/api/image',
          'width': standard_width,
          'height': standard_height,
          'sizes': [
            { width: 157, height: 256 },
            { width: 315, height: 512 },
            { width: 629, height: 1024 },
            { width: 786, height: 1280 }
          ],
          'tiles': [{ 'width': tile_size, 'scaleFactors': scale_factors }],
          'profile': ['http://iiif.io/api/image/2/level2.json', { 'formats': formats, 'qualities': qualities }]
        }
      ).to eq(instance.iiif_info(id_url, standard_width, standard_height, sizes, formats, qualities, tile_size, scale_factors))
    end
  end
end
