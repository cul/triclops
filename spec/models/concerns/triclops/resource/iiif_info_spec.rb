require 'rails_helper'

RSpec.describe Resource, type: :model do
  let(:identifier) { 'test' }
  let(:rails_root_relative_path) { File.join('spec', 'fixtures', 'files', 'sample.jpg') }
  let(:source_file_path) { Rails.root.join(rails_root_relative_path).to_s }
  let(:location_uri) { 'railsroot://' + rails_root_relative_path }
  let(:width) { 1920 }
  let(:height) { 3125 }
  let(:featured_region) { '320,616,1280,1280' }
  let(:instance) do
    described_class.new({
      identifier: identifier,
      location_uri: location_uri,
      width: width,
      height: height,
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
    let(:qualities) { ['default', 'color', 'gray', 'bitonal'] }
    let(:tile_size) { 512 }
    it 'returns the expected hash' do
      expect(
        {
          '@context': 'http://iiif.io/api/image/2/context.json',
          '@id': id_url,
          'protocol': 'http://iiif.io/api/image',
          'width': width,
          'height': height,
          'sizes': [
            { width: 157, height: 256 },
            { width: 315, height: 512 },
            { width: 629, height: 1024 },
            { width: 786, height: 1280 }
          ],
          'tiles': [{ 'width': tile_size, 'scaleFactors': [1] }],
          'profile': ['http://iiif.io/api/image/2/level2.json', { 'formats': formats, 'qualities': qualities }]
        }
      ).to eq(instance.iiif_info(id_url, width, height, sizes, formats, qualities, tile_size))
    end
  end
end
