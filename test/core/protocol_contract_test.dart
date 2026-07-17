import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/core/event.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingCoreHandler extends CoreHandlerInterface {
  final Completer<void> _completer = Completer<void>()..complete();
  final Map<ActionMethod, Object?> calls = {};

  @override
  Completer<void> get completer => _completer;

  @override
  FutureOr<bool> destroy() => true;

  @override
  Future<T?> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
  }) async {
    calls[method] = data;
    return switch (method) {
      ActionMethod.initClash => true as T,
      _ => '' as T,
    };
  }

  @override
  Future<String> preload() async => '';

  @override
  Future<bool> shutdown(bool isUser) async => true;
}

void main() {
  test('shared fixture keeps Action.data structured', () async {
    final fixture =
        json.decode(
              await File('test/fixtures/core_protocol.json').readAsString(),
            )
            as Map<String, dynamic>;
    final action = Action.fromJson(fixture['action'] as Map<String, dynamic>);

    expect(action.method, ActionMethod.updateConfig);
    expect(action.data, isA<Map<String, dynamic>>());
    expect(action.data['mixed-port'], 7890);
  });

  test('core interface sends structured request parameters', () async {
    final handler = _RecordingCoreHandler();

    await handler.init(const InitParams(homeDir: '/tmp/flclash', version: 35));
    await handler.setupConfig(
      const SetupParams(selectedMap: {'GLOBAL': 'DIRECT'}, testUrl: 'test'),
    );
    await handler.changeProxy(
      const ChangeProxyParams(groupName: 'GLOBAL', proxyName: 'DIRECT'),
    );
    await handler.sideLoadExternalProvider(providerName: 'provider', data: 'x');
    await handler.asyncTestDelay('https://example.com', 'DIRECT');

    for (final method in [
      ActionMethod.initClash,
      ActionMethod.setupConfig,
      ActionMethod.changeProxy,
      ActionMethod.sideLoadExternalProvider,
      ActionMethod.asyncTestDelay,
    ]) {
      expect(handler.calls[method], isA<Map>());
    }
  });

  test('event contract accepts batches and legacy single events', () async {
    final fixture =
        json.decode(
              await File('test/fixtures/core_protocol.json').readAsString(),
            )
            as Map<String, dynamic>;
    final result = ActionResult.fromJson(
      fixture['eventResult'] as Map<String, dynamic>,
    );

    final events = coreEventsFromData(result.data);
    expect(events, hasLength(2));
    expect(events.first.type, CoreEventType.loaded);
    expect(events.last.type, CoreEventType.delay);

    final legacy = coreEventsFromData({'type': 'loaded', 'data': 'provider-b'});
    expect(legacy.single.data, 'provider-b');
  });
}
