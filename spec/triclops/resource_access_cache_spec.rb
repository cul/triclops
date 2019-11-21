require 'rails_helper'

RSpec.describe Triclops::ResourceAccessCache do
  let(:cache_list_key) { "#{Rails.application.class.module_parent_name}:#{Rails.env}:raster_access_entries".freeze }
  let(:instance) do
    described_class.new(
      Redis.new(
        host: REDIS_CONFIG[:host],
        port: REDIS_CONFIG[:port],
        password: REDIS_CONFIG[:password],
        thread_safe: true
      ),
      cache_list_key
    )
  end

  context ".instance" do
    it "creates and returns a singleton of the correct type" do
      expect(described_class.instance).to be_a(described_class)
    end

    it "returns the same object instance when called multiple times" do
      obj1 = described_class.instance
      obj2 = described_class.instance
      expect(obj1).to equal(obj2)
    end
  end

  context '#initialize' do
    it 'successfully creates a new instance and sets up appropriate instance variables' do
      expect(instance).to be_a(described_class)
      expect(instance.instance_variable_get('@redis')).to be_a(Redis)
      expect(instance.instance_variable_get('@cache_list_key')).to eq(cache_list_key)
    end
  end

  context '#add', redis: true do
    before {
      instance.clear
    }

    it 'successfully adds entries' do
      instance.add('abc')
      expect(instance.all).to eq(['abc'])
      instance.add('xyz')
      expect(instance.all.sort).to eq(['abc', 'xyz'])
    end
  end

  context '#all', redis: true do
    before {
      instance.clear
    }

    it 'returns all added entries' do
      expect(instance.all).to eq([])
      instance.add('a')
      expect(instance.all.sort).to eq(['a'])
      instance.add('b')
      expect(instance.all.sort).to eq(['a', 'b'])
    end
  end

  context '#clear', redis: true do
    before {
      instance.clear
    }

    it 'clears all added entries when count = 1' do
      instance.add('a')
      expect(instance.all.sort).to eq(['a'])
      instance.clear
      expect(instance.all).to eq([])
    end

    it 'clears all added entries when count > 1' do
      instance.add('a')
      instance.add('b')
      instance.add('c')
      expect(instance.all.sort).to eq(['a', 'b', 'c'])
      instance.clear
      expect(instance.all).to eq([])
    end
  end
end
