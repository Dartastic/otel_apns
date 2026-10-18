// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_apns/otel_apns.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_apns-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('push.send records topic + priority + push type + collapse', () async {
    await tracedApns<String>(
      operation: 'push.send',
      invoke: () async => const ApnsCallResult(
        value: 'ok',
        result: ApnsResult(
          apnsId: 'A8B9C0D1-2345-6789-ABCD-EF0123456789',
          topic: 'com.example.app',
          pushType: 'alert',
          priority: 10,
          collapseId: 'message-42',
          environment: 'production',
          payloadBytes: 380,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('apns push.send')!);
    expect(a['apns.topic'], 'com.example.app');
    expect(a['apns.push.type'], 'alert');
    expect(a['apns.priority'], 10);
    expect(a['apns.collapse.id'], 'message-42');
    expect(a['apns.environment'], 'production');
    expect(a['apns.payload.bytes'], 380);
  });

  test('Unregistered 410 records reason + timestamp + span error', () async {
    await tracedApns<String>(
      operation: 'push.send',
      invoke: () async => const ApnsCallResult(
        value: 'ok',
        result: ApnsResult(
          deviceToken: 'aabbccdd...',
          reason: 'Unregistered',
          timestampMs: 1731600000000,
          statusCode: 410,
        ),
      ),
    );
    final s = spans.findSpanByName('apns push.send')!;
    final a = attrsOf(s);
    expect(a['apns.reason'], 'Unregistered');
    expect(a['apns.unregistered.timestamp_ms'], 1731600000000);
    expect(s.status, SpanStatusCode.Error);
  });

  test('suppression skips spans', () async {
    await runWithoutApnsInstrumentationAsync(() async {
      await tracedApns<String>(
        operation: 'push.send',
        invoke: () async => const ApnsCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('apns '), isEmpty);
  });
}
