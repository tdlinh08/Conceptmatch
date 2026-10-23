import 'package:flutter/material.dart';
import '../core/network/api_client.dart';

/// Màn hình TẠM THỜI, chỉ dùng để xác nhận Flutter app gọi được tới Backend
/// qua địa chỉ IP LAN. Sau khi xác nhận thành công, sẽ thay bằng màn hình
/// Login thật ở bước tiếp theo.
class ConnectivityTestScreen extends StatefulWidget {
  const ConnectivityTestScreen({super.key});

  @override
  State<ConnectivityTestScreen> createState() =>
      _ConnectivityTestScreenState();
}

class _ConnectivityTestScreenState extends State<ConnectivityTestScreen> {
  String _result = 'Đang kiểm tra kết nối...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() {
      _loading = true;
      _result = 'Đang kiểm tra kết nối...';
    });

    try {
      final response = await ApiClient().dio.get('');
      setState(() {
        _result = '✅ Kết nối thành công!\n\nPhản hồi từ server:\n${response.data}';
      });
    } catch (e) {
      setState(() {
        _result = '❌ Kết nối thất bại:\n$e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ConceptMatch — Test kết nối Backend')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loading) const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _result,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _testConnection,
                child: const Text('Kiểm tra lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
