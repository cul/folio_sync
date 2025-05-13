# frozen_string_literal: true

server 'diglib-rails-test1.cul.columbia.edu', user: fetch(:remote_user), roles: %w[app db web]
# In test/prod, suggest latest tag as default version to deploy
ask :branch, `git tag --sort=version:refname`.split("\n").last
