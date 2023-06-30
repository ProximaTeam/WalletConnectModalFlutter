import 'package:flutter/material.dart';
import 'package:walletconnect_modal_flutter/services/toast/toast_message.dart';
import 'package:walletconnect_modal_flutter/widgets/walletconnect_modal_theme.dart';

class WalletConnectModalToast extends StatefulWidget {
  const WalletConnectModalToast({
    super.key,
    required this.message,
  });

  final ToastMessage message;

  @override
  State<WalletConnectModalToast> createState() =>
      _WalletConnectModalToastState();
}

class _WalletConnectModalToastState extends State<WalletConnectModalToast>
    with SingleTickerProviderStateMixin {
  static const fadeInTime = 200;
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: fadeInTime),
      vsync: this,
    );
    _opacityAnimation = Tween(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward().then((_) {
      Future.delayed(
        widget.message.duration -
            const Duration(
              milliseconds: fadeInTime * 2,
            ),
      ).then((_) {
        _controller.reverse();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WalletConnectModalTheme theme = WalletConnectModalTheme.of(context);

    return Positioned(
      top: 20.0,
      left: 20.0,
      right: 20.0,
      child: Center(
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: widget.message.type == ToastType.info
                  ? theme.data.background200
                  : theme.data.error,
              borderRadius: BorderRadius.circular(
                theme.data.radius3XS,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.message.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.data.foreground100,
                  fontSize: 18.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
