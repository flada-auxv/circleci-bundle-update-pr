require "circleci/bundle/update/pr/version"
require "octokit"
require "compare_linker"

module Circleci
  module Bundle
    module Update
      module Pr
        def self.create_if_needed(git_username: nil, git_email: nil)
          raise "$CIRCLE_PROJECT_USERNAME isn't set" unless ENV['CIRCLE_PROJECT_USERNAME']
          raise "$CIRCLE_PROJECT_REPONAME isn't set" unless ENV['CIRCLE_PROJECT_REPONAME']
          raise "$GITHUB_ACCESS_TOKEN isn't set" unless ENV['GITHUB_ACCESS_TOKEN']
          return unless need?
          repo_full_name = "#{ENV['CIRCLE_PROJECT_USERNAME']}/#{ENV['CIRCLE_PROJECT_REPONAME']}"
          now = Time.now
          branch = "bundle-update-#{now.strftime('%Y%m%d%H%M%S')}"
          create_branch(git_username, git_email, branch)
          pull_request = create_pull_request(repo_full_name, branch, now)
          add_comment_of_compare_linker(repo_full_name, pull_request[:number])
        end

        def self.need?
          return false unless ENV['CIRCLE_BRANCH'] == "master"
          system("bundle update")
          `git status -sb 2> /dev/null`.include?("Gemfile.lock")
        end
        private_class_method :need?

        def self.create_branch(git_username, git_email, branch)
          system("git config user.name #{git_username}")
          system("git config user.email #{git_email}")
          system("git add Gemfile.lock")
          system("git commit -m '$ bundle update'")
          system("git branch -M #{branch}")
          system("git push origin #{branch}")
        end
        private_class_method :create_branch

        def self.create_pull_request(repo_full_name, branch, now)
          title = "bundle update at #{now.strftime('%Y-%m-%d %H:%M:%S %Z')}"
          body  = "auto generated by [CircleCI of #{ENV['CIRCLE_PROJECT_REPONAME']}](https://circleci.com/gh/#{repo_full_name})"
          client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])
          client.create_pull_request(repo_full_name, "master", branch, title, body)
        end
        private_class_method :create_pull_request

        def self.add_comment_of_compare_linker(repo_full_name, pr_number)
          ENV["OCTOKIT_ACCESS_TOKEN"] = ENV["GITHUB_ACCESS_TOKEN"]
          compare_linker = CompareLinker.new(repo_full_name, pr_number)
          compare_linker.formatter = CompareLinker::Formatter::Markdown.new

          comment = <<-EOC
#{compare_linker.make_compare_links.to_a.join("\n")}

Powered by [compare_linker](https://rubygems.org/gems/compare_linker)
          EOC

          compare_linker.add_comment(repo_full_name, pr_number, comment)
        end
        private_class_method :add_comment_of_compare_linker
      end
    end
  end
end
