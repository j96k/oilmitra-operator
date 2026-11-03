import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';

/// Small dialog for pointing the app at another server. Used from login and
/// profile; returns true when the new address answered a ping.
class ServerAddressDialog extends StatefulWidget {
  const ServerAddressDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const ServerAddressDialog());
    return ok ?? false;
  }

  @override
  State<ServerAddressDialog> createState() => _ServerAddressDialogState();
}

class _ServerAddressDialogState extends State<ServerAddressDialog> {
  late final TextEditingController _ctrl;
  bool _testing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: Api.instance.baseUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    setState(() {
      _testing = true;
      _message = null;
    });
    await Api.instance.setBaseUrl(_ctrl.text);
    final ok = await Api.instance.ping();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _testing = false;
        _message = 'Could not reach that address.';
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Server address', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'For a phone on the same Wi-Fi, use your PC\'s address — e.g. http://192.168.1.5:8000',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 12),
        TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'http://192.168.1.5:8000')),
        if (_message != null) ...[
          const SizedBox(height: 10),
          Text(_message!, style: const TextStyle(fontSize: 12.5, color: AppColors.cancelled)),
        ],
      ]),
      actions: [
        TextButton(onPressed: _testing ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _testing ? null : _testAndSave,
          child: Text(_testing ? 'Testing…' : 'Test & save'),
        ),
      ],
    );
  }
}
