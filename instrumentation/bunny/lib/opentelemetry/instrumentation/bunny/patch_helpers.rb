# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module Instrumentation
    module Bunny
      # The PatchHelper module provides functionality shared between patches.
      #
      # For additional details around trace messaging semantics
      # See https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/trace/semantic_conventions/messaging.md#messaging-attributes
      module PatchHelpers
        def self.with_send_span(channel, tracer, exchange, routing_key, &block)
          attributes = basic_attributes(channel, exchange, routing_key)
          destination = destination_name(exchange, routing_key)

          tracer.in_span("#{destination} send", attributes: attributes, kind: :producer, &block)
        end

        def self.with_receive_span(channel, tracer, delivery_info, properties, &block)
          exchange = delivery_info.exchange
          routing_key = delivery_info.routing_key
          attributes = basic_attributes(channel, exchange, routing_key)
          destination = destination_name(exchange, routing_key)
          parent_context, links = extract_context(properties[:headers])

          OpenTelemetry::Context.with_current(parent_context) do
            tracer.in_span("#{destination} receive", links: links, attributes: attributes, kind: :consumer, &block)
          end
        end

        def self.with_process_span(channel, tracer, delivery_info, properties, &block)
          destination = destination_name(delivery_info[:exchange], delivery_info[:routing_key])
          parent_context, links = extract_context(properties[:headers])

          OpenTelemetry::Context.with_current(parent_context) do
            tracer.in_span("#{destination} process", links: links, kind: :consumer, &block)
          end
        end

        def self.destination_name(exchange, routing_key)
          [exchange, routing_key].compact.join('.')
        end

        def self.extract_context(headers)
          parent_context = OpenTelemetry.propagation.text.extract(headers)
          span_context = OpenTelemetry::Trace.current_span(parent_context).context
          links = [OpenTelemetry::Trace::Link.new(span_context)] if span_context.valid?

          [parent_context, links]
        end

        def self.basic_attributes(channel, exchange, routing_key)
          attributes = {
            'messaging.system' => 'rabbitmq',
            'messaging.destination' => exchange,
            'messaging.destination_kind' => destination_kind(channel, exchange),
            'messaging.protocol' => 'AMQP',
            'messaging.protocol_version' => ::Bunny.protocol_version,
            'net.peer.name' => channel.connection.host,
            'net.peer.port' => channel.connection.port
          }
          attributes['messaging.rabbitmq.routing_key'] = routing_key if routing_key
          attributes
        end

        def self.destination_kind(channel, exchange)
          # The default exchange with no name is always a direct exchange
          # https://github.com/ruby-amqp/bunny/blob/master/lib/bunny/exchange.rb#L33
          return 'direct' if exchange == ''

          # All exchange types https://www.rabbitmq.com/tutorials/amqp-concepts.html#exchanges
          # except direct exchanges are mapped to topic
          return 'direct' if channel.find_exchange(exchange)&.type == :direct

          'topic'
        end
      end
    end
  end
end