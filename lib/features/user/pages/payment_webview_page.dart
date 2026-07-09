import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class PaymentWebViewPage extends StatefulWidget {
  final String paymentUrl;
  final String serviceId;
  final bool isAdditionalPayment;
  final String? additionalCostId;

  const PaymentWebViewPage({
    Key? key,
    required this.paymentUrl,
    required this.serviceId,
    this.isAdditionalPayment = false,
    this.additionalCostId,
  }) : super(key: key);

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // KEAMANAN: status pembayaran TIDAK lagi ditulis dari client. Sumber
  // kebenaran adalah webhook Xendit (Edge Function xendit-webhook) yang
  // memperbarui services.status via service-role; RLS menolak client
  // menandai PAID/PROCESSED. Redirect di sini hanya untuk feedback UI —
  // status final muncul di halaman riwayat lewat realtime/polling.

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
                AwesomeDialog(
                  context: context,
                  dialogType: DialogType.success,
                  animType: AnimType.bottomSlide,
                  title: 'Pembayaran Diterima',
                  desc:
                      'Pembayaran Anda sedang dikonfirmasi oleh sistem. Status service akan diperbarui otomatis di halaman riwayat.',
                  btnOkOnPress: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/history',
                      (route) => false,
                    );
                  },
                  btnOkText: 'OK',
                  btnOkColor: Colors.blue,
                ).show();
                return NavigationDecision.prevent;
              } else if (request.url.contains('failed')) {
                AwesomeDialog(
                  context: context,
                  dialogType: DialogType.error,
                  animType: AnimType.bottomSlide,
                  title: 'Pembayaran Gagal',
                  desc: 'Mohon maaf, pembayaran Anda gagal. Silakan coba lagi.',
                  btnOkOnPress: () {
                    if (mounted) Navigator.pop(context);
                  },
                  btnOkText: 'OK',
                  btnOkColor: Colors.red,
                ).show();
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
