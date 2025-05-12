# frozen_string_literal: true

server "diglib-rails-prod1.cul.columbia.edu", user: fetch(:remote_user), roles: %w[app db web]
# In test/prod, suggest latest tag as default version to deploy
# ask :branch, `git tag --sort=version:refname`.split("\n").last
# however, for now we will go with the current branch (as it is in dev)
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp
