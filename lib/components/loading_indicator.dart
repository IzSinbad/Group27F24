import 'package:flutter/material.dart';

// A customizable loading indicator that provides visual feedback during operations
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  final bool isLinear;
  final double? value;

  const LoadingIndicator({
    Key? key,
    this.message,
    this.size = 40.0,
    this.color,
    this.isLinear = false,
    this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? theme.primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLinear)
          LinearProgressIndicator(
            value: value,
            valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
            backgroundColor: indicatorColor.withOpacity(0.2),
          )
        else
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value,
              valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
              strokeWidth: 4.0,
            ),
          ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// A loading indicator specifically for full-screen loading states
class FullScreenLoading extends StatelessWidget {
  final String? message;
  final Color? backgroundColor;

  const FullScreenLoading({
    Key? key,
    this.message,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.white,
      child: Center(
        child: LoadingIndicator(message: message),
      ),
    );
  }
}

// A loading indicator that shows progress with additional details
class DetailedLoadingIndicator extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double progress;
  final String? progressText;

  const DetailedLoadingIndicator({
    Key? key,
    required this.title,
    this.subtitle,
    required this.progress,
    this.progressText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: Colors.grey[200],
              ),
              Text(
                progressText ?? '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}