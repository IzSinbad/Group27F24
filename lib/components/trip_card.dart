import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;

  const TripCard({
    Key? key,
    required this.trip,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Format numbers for display
    final numberFormat = NumberFormat('#,##0.0');

    // Calculate trip duration
    final duration = trip.endTime!.difference(trip.startTime);

    // Format date for display
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trip date and time
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(trip.startTime),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${timeFormat.format(trip.startTime)} - '
                        '${timeFormat.format(trip.endTime!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const Divider(height: 24),

              // Trip statistics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatColumn(
                    context,
                    Icons.route,
                    'Distance',
                    '${numberFormat.format(trip.distance)} km',
                  ),
                  _buildStatColumn(
                    context,
                    Icons.speed,
                    'Avg Speed',
                    '${numberFormat.format(trip.averageSpeed)} km/h',
                  ),
                  _buildStatColumn(
                    context,
                    Icons.timer,
                    'Duration',
                    _formatDuration(duration),
                  ),
                ],
              ),

              // Show warnings if any exist
              if (trip.warnings.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${trip.warnings.length} speed warning'
                          '${trip.warnings.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(
      BuildContext context,
      IconData icon,
      String label,
      String value,
      ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hr ${minutes} min';
    }
    return '$minutes min';
  }
}