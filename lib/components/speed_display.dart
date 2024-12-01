import 'package:flutter/material.dart';

class SpeedDisplay extends StatelessWidget {
  final double currentSpeed;
  final double maxSpeed;
  final double? speedLimit;

  const SpeedDisplay({
    Key? key,
    required this.currentSpeed,
    required this.maxSpeed,
    this.speedLimit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isOverSpeedLimit = speedLimit != null && currentSpeed > speedLimit!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverSpeedLimit ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Current Speed',
            style: TextStyle(
              color: isOverSpeedLimit ? Colors.red : Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currentSpeed.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: isOverSpeedLimit ? Colors.red : Colors.black,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  ' km/h',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}