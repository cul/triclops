FactoryBot.define do
  factory :resource do
    identifier { 'test-resource' }
    location_uri { "railsroot://#{File.join('spec', 'fixtures', 'files', 'sample.jpg')}" }
    width { 1920 }
    height { 3125 }
    featured_region { '320,616,1280,1280' }
  end
end
