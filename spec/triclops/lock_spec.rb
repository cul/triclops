require 'rails_helper'

RSpec.describe Triclops::Lock do
  let(:key_prefix) { 'prefix:' }
  let(:lock_timeout) { 5 } # seconds
  let(:lock_retry_count) { 6 }
  let(:lock_retry_delay) { 1 } # seconds
  let(:redis) do
    Redis.new(
      host: REDIS_CONFIG[:host],
      port: REDIS_CONFIG[:port],
      password: REDIS_CONFIG[:password],
      thread_safe: true
    )
  end
  let(:instance) do
    described_class.new(
      redis,
      lock_timeout,
      lock_retry_count,
      lock_retry_delay,
      key_prefix
    )
  end

  context '.instance' do
    it 'creates and returns a singleton of the correct type' do
      expect(described_class.instance).to be_a(described_class)
    end

    it 'returns the same object instance when called multiple times' do
      obj1 = described_class.instance
      obj2 = described_class.instance
      expect(obj1).to equal(obj2)
    end
  end

  context '#initialize' do
    it 'successfully creates a new instance and sets up appropriate instance variables' do
      expect(instance).to be_a(described_class)
      expect(instance.instance_variable_get('@lock_manager')).to be_a(Redlock::Client)
      expect(instance.instance_variable_get('@key_prefix')).to eq(key_prefix)
    end
  end

  context '#with_blocking_lock', redis: true do
    let(:key) { 'lock_key' }
    it 'runs the passed in-block exactly once' do
      num = 0
      instance.with_blocking_lock(key) do
        num += 1
      end
      expect(num).to eq(1)
    end

    context "concurrent attempts to obtain a lock" do
      # set a LONGER lock timeout and a SHORTER retry duration
      let(:lock_retry_count) { 2 }
      let(:lock_retry_delay) { 2 }
      let(:lock_retry_duration) { lock_retry_count * lock_retry_delay }
      let(:lock_timeout) { lock_retry_duration * 2 } # lock_timeout will be longer than retry duration
      let(:sleep_time_less_than_retry_duration) { lock_retry_duration - 1 }
      let(:sleep_time_longer_than_retry_duration) { lock_retry_duration + 1 }

      it "waits for the existing lock to be released" do
        start_time = Time.current
        num = 0
        t1 = Thread.new {
          instance.with_blocking_lock(key) {
            sleep sleep_time_less_than_retry_duration
            num += 1
          }
        }
        sleep 0.1
        t2 = Thread.new {
          instance.with_blocking_lock(key) {
            # We expect that the code here in Thread t2 won't execute until
            # Thread t1's code has released its lock, so that's why we expect
            # a minimum delay of sleep_time_less_than_retry_duration.
            expect(Time.current - start_time).to be > sleep_time_less_than_retry_duration
            num += 2
          }
        }
        t1.join
        t2.join
        # Make sure both threads obtained a lock and ran their blocks.
        expect(num).to eq(3)
      end

      it "raises an error and doesn't execute the second lock's block when a timeout is exceeded" do
        num = 0
        t1 = Thread.new {
          instance.with_blocking_lock(key) {
            sleep sleep_time_longer_than_retry_duration
            num += 1
          }
        }
        sleep 0.1

        t2 = Thread.new {
          expect {
            instance.with_blocking_lock(key) {
              num += 2
            }
          }.to raise_error(Redlock::LockError)
        }

        t1.join
        t2.join
        # Make sure that only the first thread obtained a lock and ran its block.
        expect(num).to eq(1)
      end
    end
  end
end
