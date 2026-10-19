// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_apns_suppression.dart';

const _tracerName = 'dartastic_otel_libs_apns';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class ApnsResult {
  /// Creates a result.
  const ApnsResult({
    this.apnsId,
    this.topic,
    this.pushType,
    this.priority,
    this.collapseId,
    this.environment,
    this.deviceToken,
    this.payloadBytes,
    this.reason,
    this.timestampMs,
    this.statusCode,
  });

  /// `apns-id` response header — unique notification id from Apple.
  final String? apnsId;

  /// Bundle id (typically the app's iOS bundle).
  final String? topic;

  /// `alert` / `background` / `voip` / `complication` / `fileprovider`
  /// / `mdm` / `liveactivity` / `pushtotalk` / `location`.
  final String? pushType;

  /// 10 (immediate, default for alerts) / 5 (conserve power) / 1
  /// (background/low priority, throttled).
  final int? priority;

  /// `apns-collapse-id` — newest collapses prior with same id.
  final String? collapseId;

  /// `production` / `development` (sandbox).
  final String? environment;

  /// Device token (64+ hex chars). Logged as id only, never payload.
  final String? deviceToken;

  /// Size of the JSON payload Apple accepted/rejected (alert max 4096,
  /// VoIP max 5120).
  final int? payloadBytes;

  /// Apple's reason string when status != 200. Common values:
  /// `BadDeviceToken` / `Unregistered` / `PayloadTooLarge` /
  /// `TopicDisallowed` / `BadCertificate` / `ExpiredProviderToken` /
  /// `TooManyRequests` / `BadPriority`.
  final String? reason;

  /// `timestamp` (ms) returned with `Unregistered` indicating when the
  /// token became invalid — feed this back to your device registry.
  final int? timestampMs;

  /// HTTP/2 status (200 success, 400 bad request, 410 unregistered,
  /// 413 payload too large, 429 too many requests, 500/503 server).
  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class ApnsCallResult<T> {
  /// Creates a call result.
  const ApnsCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final ApnsResult? result;
}

/// Wraps an APNs request in a CLIENT span. [operation] is one of
/// `push.send`, `push.send_batch`, `topic.subscribe`,
/// `topic.unsubscribe`.
Future<T> tracedApns<T>({
  required String operation,
  required Future<ApnsCallResult<T>> Function() invoke,
}) async {
  if (apnsInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'apns',
    'rpc.method': operation,
    'apns.operation': operation,
  };

  final span = _tracer().startSpan(
    'apns $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.apnsId != null) {
        extras.add(OTelAPI.attributeString('apns.id', r.result!.apnsId!));
      }
      if (r.result!.topic != null) {
        extras.add(OTelAPI.attributeString('apns.topic', r.result!.topic!));
      }
      if (r.result!.pushType != null) {
        extras.add(OTelAPI.attributeString(
          'apns.push.type',
          r.result!.pushType!,
        ));
      }
      if (r.result!.priority != null) {
        extras.add(OTelAPI.attributeInt('apns.priority', r.result!.priority!));
      }
      if (r.result!.collapseId != null) {
        extras.add(OTelAPI.attributeString(
          'apns.collapse.id',
          r.result!.collapseId!,
        ));
      }
      if (r.result!.environment != null) {
        extras.add(OTelAPI.attributeString(
          'apns.environment',
          r.result!.environment!,
        ));
      }
      if (r.result!.deviceToken != null) {
        extras.add(OTelAPI.attributeString(
          'apns.device.token',
          r.result!.deviceToken!,
        ));
      }
      if (r.result!.payloadBytes != null) {
        extras.add(OTelAPI.attributeInt(
          'apns.payload.bytes',
          r.result!.payloadBytes!,
        ));
      }
      if (r.result!.reason != null) {
        extras.add(OTelAPI.attributeString('apns.reason', r.result!.reason!));
      }
      if (r.result!.timestampMs != null) {
        extras.add(OTelAPI.attributeInt(
          'apns.unregistered.timestamp_ms',
          r.result!.timestampMs!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'APNs ${r.result!.statusCode}'
            '${r.result!.reason != null ? " ${r.result!.reason}" : ""}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
