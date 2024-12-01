import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';

class SpeedWarningCard extends StatelessWidget {
  final SpeedWarning warning;
  final VoidCallback? onTap;
  final bool expanded;

  const SpeedWarningCard({
    Key? key,
    required this.warning,
    this.onTap,
    this.expanded = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss');
    final speedDifference = warning.speed - warning.speedLimit;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      color: Colors.red.shade50,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Speed Limit Exceeded',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          timeFormat.format(warning.timestamp),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '+${speedDifference.toStringAsFixed(1)} km/h',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Actual Speed',
                  '${warning.speed.toStringAsFixed(1)} km/h',
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Speed Limit',
                  '${warning.speedLimit.toStringAsFixed(0)} km/h',
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Location',
                  '${warning.location.latitude.toStringAsFixed(6)}, '
                      '${warning.location.longitude.toStringAsFixed(6)}',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}