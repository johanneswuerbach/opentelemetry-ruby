# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'opentelemetry'

module OpenTelemetry
  module Instrumentation
    # Contains the OpenTelemetry instrumentation for the Sidekiq gem
    module Sidekiq
    end
  end
end

require_relative './sidekiq/instrumentation'
require_relative './sidekiq/version'
