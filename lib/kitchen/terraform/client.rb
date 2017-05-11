# frozen_string_literal: true

# Copyright 2016 New Context Services, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "kitchen/terraform"
require "terraform/command_factory"
require "terraform/no_output_parser"
require "terraform/output_parser"
require "terraform/shell_out"

# Client to execute commands
class ::Kitchen::Terraform::Client
  def apply_constructively
    apply plan_command: factory.plan_command
  end

  def apply_destructively
    apply plan_command: factory.destructive_plan_command
  end

  def each_output_name(&block)
    output_parser(name: "").each_name &block
  end

  def iterate_output(name:, &block)
    output_parser(name: name).iterate_parsed_output &block
  end

  def load_state(&block)
    execute command: factory.show_command do |state| /\w+/.match state, &block end
  end

  def output(name:)
    output_parser(name: name).parsed_output
  end

  private

  attr_accessor :apply_timeout, :cli, :config, :factory, :logger

  def apply(plan_command:)
    execute command: factory.validate_command
    execute command: factory.get_command
    execute command: plan_command
    ::Kitchen::Terraform::Client::Apply.call config: config, logger: logger
  end

  def execute(command:, &block)
    ::Terraform::ShellOut.new(cli: cli, command: command, logger: logger).execute &block
  end

  def initialize(config: {}, logger:)
    self.apply_timeout = config[:apply_timeout]
    self.cli = config[:cli]
    self.config = config
    self.factory = ::Terraform::CommandFactory.new config: config
    self.logger = logger
  end

  def output_parser(name:)
    execute command: factory.output_command(target: name) do |value|
      return ::Terraform::OutputParser.new output: value
    end
  rescue ::Kitchen::StandardError => exception
    /no outputs/.match? exception.message or raise exception
    ::Terraform::NoOutputParser.new
  end
end

require "kitchen/terraform/client/apply"
