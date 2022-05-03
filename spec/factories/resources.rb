FactoryBot.define do
  factory :resource do
    transient do
      sequence :identifier_counter, 1
    end

    identifier { "test-resource-#{identifier_counter}" }
    secondary_identifier { "test-resource-alt-id-#{identifier_counter}" }
    location_uri { "railsroot://#{File.join('spec', 'fixtures', 'files', 'sample.jpg')}" }
    width { 1920 }
    height { 3125 }
    featured_region { '320,616,1280,1280' }
  end
end
