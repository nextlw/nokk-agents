# frozen_string_literal: true

require_relative "lib/agents/version"

Gem::Specification.new do |spec|
  spec.name = "nokk-agents"
  spec.version = Agents::VERSION
  spec.authors = ["Nokk"]
  spec.email = ["dev@nokk.com.br"]

  spec.summary = "Nokk AI Agents SDK - Multi-agent orchestration framework"
  spec.description = "Fork of ai-agents with Nokk-specific extensions for multi-agent AI workflows"
  spec.homepage = "https://github.com/nextlw/nokk-agents"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby_llm", "~> 1.9"
end
