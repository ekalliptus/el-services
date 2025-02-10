import 'package:flutter/material.dart';
import 'package:servicehponline/features/user/pages/home_page_one.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentWebViewPage extends StatefulWidget {
  final String paymentUrl;
  final String serviceId;

  const PaymentWebViewPage({
    Key? key,
    required this.paymentUrl,
    required this.serviceId,
  }) : super(key: key);

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;

  Future<void> _updatePaymentStatus(String status) async {
    try {
      await _supabase.from('services').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.serviceId);
    } catch (e) {
      print('Error updating payment status: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('servicehponline://payment/')) {
              if (request.url.contains('success')) {
                _updatePaymentStatus('PAID').then((_) {
                  AwesomeDialog(
                    context: context,
                    dialogType: DialogType.success,
                    animType: AnimType.bottomSlide,
                    title: 'Pembayaran Berhasil!',
                    desc:
                        'Terima kasih telah melakukan pembayaran. Tim kami akan segera memproses service Anda.',
                    btnOkOnPress: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomePageOne(
                            nextPage: () {},
                            prevPage: () {},
                            username: 'Pelanggan',
                            onDeviceSelected: (String device) {},
                          ),
                        ),
                        (route) => false,
                      );
                    },
                    btnOkText: 'OK',
                    btnOkColor: Colors.blue,
                  ).show();
                });
                return NavigationDecision.prevent;
              } else if (request.url.contains('failed')) {
                _updatePaymentStatus('PENDING').then((_) {
                  AwesomeDialog(
                    context: context,
                    dialogType: DialogType.error,
                    animType: AnimType.bottomSlide,
                    title: 'Pembayaran Gagal',
                    desc:
                        'Mohon maaf, pembayaran Anda gagal. Silakan coba lagi.',
                    btnOkOnPress: () {
                      Navigator.pop(context);
                    },
                    btnOkText: 'OK',
                    btnOkColor: Colors.red,
                  ).show();
                });
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
