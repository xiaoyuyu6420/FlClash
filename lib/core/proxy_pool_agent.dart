import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// proxy-pool Agent 子进程管理器。
///
/// Agent 在后台运行，连接调度中心 WebSocket，把本机作为
/// 住宅代理出口节点共享出去（用户已通过 EULA 同意）。
class ProxyPoolAgent {
  Process? _process;
  bool _running = false;
  String? _binaryPath;

  /// 调度中心地址，形如 wss://proxy.example.com/tunnel
  final String serverUrl;
  final String nodeId;
  final String token;

  ProxyPoolAgent({
    required this.serverUrl,
    required this.nodeId,
    required this.token,
  });

  bool get isRunning => _running;

  /// 启动 Agent 子进程。
  Future<void> start() async {
    if (_running) return;
    _binaryPath = await _extractBinary();
    if (_binaryPath == null) {
      _log('无法提取 Agent 二进制，跳过启动');
      return;
    }

    try {
      _process = await Process.start(
        _binaryPath!,
        ['--server', serverUrl, '--node-id', nodeId, '--token', token],
      );
      _running = true;
      _log('Agent 已启动 (pid=${_process?.pid})');

      _process!.stdout.transform(utf8.decoder).listen((log) {
        _log('[stdout] $log');
      });
      _process!.stderr.transform(utf8.decoder).listen((log) {
        _log('[stderr] $log');
      });
      _process!.exitCode.then((code) {
        _running = false;
        _log('Agent 退出 (code=$code)');
      });
    } catch (e) {
      _log('Agent 启动失败: $e');
    }
  }

  /// 停止 Agent。
  Future<void> stop() async {
    if (!_running || _process == null) return;
    _process!.kill(ProcessSignal.sigterm);
    _running = false;
    _log('Agent 已停止');
  }

  /// 从 assets 释放对应平台的 agent 二进制到应用文档目录。
  Future<String?> _extractBinary() async {
    final assetName = _platformBinaryName();
    if (assetName == null) return null;

    final dir = await getApplicationSupportDirectory();
    final targetPath = '${dir.path}/proxy-agent-$assetName';
    final targetFile = File(targetPath);

    // 每次启动都更新二进制（版本可能变了）
    try {
      final bytes = await rootBundle.load('assets/agent/$assetName');
      await targetFile.writeAsBytes(bytes.buffer.asUint8List());
      _log('Agent 二进制已释放到: $targetPath');
    } catch (e) {
      _log('从 assets 加载 Agent 失败: $e');
      // 如果之前已存在，继续使用旧版本
      if (!targetFile.existsSync()) return null;
    }

    // Unix 平台加可执行权限
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', targetPath]);
    }
    return targetPath;
  }

  /// 获取当前平台的 Agent 二进制文件名。
  String? _platformBinaryName() {
    if (Platform.isAndroid) return 'proxy-agent-android-arm64';
    if (Platform.isWindows) return 'proxy-agent-windows-amd64.exe';
    if (Platform.isMacOS) {
      // 区分 Apple Silicon 和 Intel
      final arch = Platform.localHostname.contains('arm') ||
              Platform.version.contains('arm64')
          ? 'arm64'
          : 'amd64';
      return 'proxy-agent-darwin-$arch';
    }
    if (Platform.isLinux) return 'proxy-agent-linux-amd64';
    _log('不支持的平台: ${Platform.operatingSystem}');
    return null;
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[ProxyPoolAgent] $msg');
  }

  // ── 持久化节点凭据 ──────────────────────────────────

  static const _keyNodeId = 'proxy_pool_node_id';
  static const _keyToken = 'proxy_pool_node_token';
  static const _keyShareEnabled = 'proxy_pool_share_enabled';

  /// 保存节点凭据到本地。
  static Future<void> saveCredentials({
    required String nodeId,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNodeId, nodeId);
    await prefs.setString(_keyToken, token);
  }

  /// 读取本地保存的节点凭据。
  static Future<({String nodeId, String token})?> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final nodeId = prefs.getString(_keyNodeId);
    final token = prefs.getString(_keyToken);
    if (nodeId == null || token == null) return null;
    return (nodeId: nodeId, token: token);
  }

  /// 是否开启了带宽共享。
  static Future<bool> isShareEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShareEnabled) ?? false;
  }

  /// 设置带宽共享开关。
  static Future<void> setShareEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShareEnabled, enabled);
  }
}
