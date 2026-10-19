// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_apns/otel_apns.dart';

/// Traces APNs calls with OpenTelemetry.
///
/// `otel_apns` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each APNs call in
/// [tracedApns]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'apns-example');

  // Wraps an APNs request in a CLIENT span.
  final apnsId = await tracedApns<String>(
    operation: 'push.send',
    invoke: () async {
      // Make the APNs call here, then report what it returned.
      const id = 'apns_8f3a2c';
      return const ApnsCallResult(
          value: id,
          result: ApnsResult(
              apnsId: 'apns-id',
              topic: 'orders',
              pushType: 'alert',
              priority: 1,
              collapseId: 'apns-collapse-id',
              environment: 'production',
              deviceToken: 'example',
              payloadBytes: 512,
              reason: 'BadDeviceToken',
              timestampMs: 120,
              statusCode: 201));
    },
  );
  OTelLog.info('tracedApns push.send returned $apnsId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutApnsInstrumentationAsync.
  await runWithoutApnsInstrumentationAsync(
    () => tracedApns<String>(
      operation: 'push.send',
      invoke: () async {
        const id = 'apns_8f3a2c';
        return const ApnsCallResult(
            value: id,
            result: ApnsResult(
                apnsId: 'apns-id',
                topic: 'orders',
                pushType: 'alert',
                priority: 1,
                collapseId: 'apns-collapse-id',
                environment: 'production',
                deviceToken: 'example',
                payloadBytes: 512,
                reason: 'BadDeviceToken',
                timestampMs: 120,
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
