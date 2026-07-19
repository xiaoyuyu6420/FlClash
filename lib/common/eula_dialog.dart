import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 带宽共享用户协议弹窗。
/// 返回 true 表示用户同意共享带宽，false 表示拒绝（仅用 VPN）。
class EulaDialog {
  static const _keyAccepted = 'bandwidth_share_accepted';
  static const _keyVersion = 'eula_version';
  static const _currentVersion = 1;

  /// 检查是否需要展示（首次或版本更新时）。
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_keyAccepted) ?? false;
    final version = prefs.getInt(_keyVersion) ?? 0;
    return !accepted || version < _currentVersion;
  }

  /// 记录用户选择。
  static Future<void> setAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAccepted, accepted);
    await prefs.setInt(_keyVersion, _currentVersion);
  }

  /// 展示弹窗，返回用户是否同意。
  static Future<bool> show(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const _EulaContent(),
        ) ??
        false;
  }
}

class _EulaContent extends StatelessWidget {
  const _EulaContent();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('用户协议与带宽共享'),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('欢迎使用 MyVPN',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text(
              '本应用提供 VPN 翻墙服务。为了让服务更经济实惠，'
              '在您使用期间，应用会共享您的部分闲置网络带宽，'
              '作为代理出口节点供其他用户使用。',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '• 您可以在设置中随时关闭带宽共享\n'
              '• 关闭后 VPN 仍可正常使用\n'
              '• 共享的带宽有限，不会显著影响您的网速\n'
              '• 我们不会收集您的浏览记录或个人信息',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            SizedBox(height: 12),
            Text(
              '点击"同意并开启"表示您理解并同意上述条款。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('仅用 VPN'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('同意并开启'),
        ),
      ],
    );
  }
}
