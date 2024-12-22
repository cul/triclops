FactoryBot.define do
  factory :resource do
    transient do
      sequence :identifier_counter, 1
    end

    identifier { "test-resource-#{identifier_counter}" }
    has_view_limitation { false }
    source_uri { "railsroot://#{File.join('spec', 'fixtures', 'files', 'sample.jpg')}" }
    standard_width { 1920 }
    standard_height { 3125 }
    limited_width { standard_width > standard_height ? 768 : ((768.to_f / standard_height) * standard_width).round }
    limited_height { standard_height > standard_width ? 768 : ((768.to_f / standard_width) * standard_height).round }
    featured_width { 768 }
    featured_height { 768 }
    featured_region { '320,616,1280,1280' }
    pcdm_type { BestType::PcdmTypeLookup::IMAGE }
    status { Resource.statuses[:pending] }
    accessed_at { DateTime.parse('2024-01-01T01:23:45-05:00') }

    trait :ready do
      status { Resource.statuses[:ready] }
    end

    trait :with_view_limitation do
      has_view_limitation { true }
    end
  end
end
