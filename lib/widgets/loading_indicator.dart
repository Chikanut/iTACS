// lib/widgets/loading_indicator.dart
import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  final bool showBackground;
  
  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 24.0,
    this.color,
    this.showBackground = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.0,
        color: color ?? theme.colorScheme.primary,
      ),
    );
    
    if (message != null) {
      indicator = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(height: 8),
          Text(
            message!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color ?? theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    
    if (showBackground) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: indicator,
      );
    }
    
    return indicator;
  }
}

class OverlayLoadingIndicator extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  
  const OverlayLoadingIndicator({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
  });
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black26,
              child: Center(
                child: LoadingIndicator(
                  message: message,
                  showBackground: true,
                ),
              ),
            ),
          ),
      ],
    );
  }
}