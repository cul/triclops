# Triclops: A triple-eye-f (IIIF) Server

Triclops is a cool IIIF server.

## Requirements

- Ruby 2.6
- Redis 3
- More to come

## First-Time Setup (for developers)

```
git clone git@github.com:cul/ren-triclops.git # Clone the repo
cd ren-triclops # Switch to the application directory
# Note: Make sure rvm has selected the correct ruby version. You may need to move out of the directory and back into it force rvm to use the ruby version specified in .ruby_version.
bundle install # Install gem dependencies
yarn install # this assumes you have node and yarn installed (tested with Node 8 and Node 10)
bundle exec rake triclops:setup:config_files # Set up config files like redis.yml and resque.yml
bundle exec rake db:migrate # Run database migrations
rails s -p 3000 # Start the application using rails server
```

## Testing
Our testing suite runs Rubocop and then runs all of our ruby tests. Travis CI will automatically run the test suite for every commit and pull request.

To run the continuous integration test suite locally on your machine run:
```
bundle exec rake triclops:ci
```