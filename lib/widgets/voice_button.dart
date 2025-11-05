// lib/widgets/voice_button.dart

import 'package:flutter/material.dart';

/// A small reusable animated microphone button used to toggle speech input.
///
/// Provides a `isListening` boolean to change appearance and an `onPressed`
/// callback. The animation is a pulsing circular glow while listening.
class VoiceButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onPressed;
  final double size;

  const VoiceButton({super.key, required this.isListening, required this.onPressed, this.size = 72});

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pulse = Tween<double>(begin: 0.0, end: 12.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.isListening) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isListening && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final glow = widget.isListening ? _pulse.value : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              // glow
              Container(
                width: widget.size + glow,
                height: widget.size + glow,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.fromRGBO(255, 0, 0, widget.isListening ? 0.14 : 0.06),
                ),
              ),
              Material(
                color: widget.isListening ? Colors.red : Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onPressed,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Icon(
                      widget.isListening ? Icons.mic : Icons.mic_none,
                      size: widget.size / 2.2,
                      color: widget.isListening ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
