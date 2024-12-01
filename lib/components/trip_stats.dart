import 'package:flutter/material.dart';

class TripStats extends StatelessWidget {
  final double distance;
  final Duration duration;
  final double maxSpeed;

  const TripStats({
    Key? key,
    required this.distance,
    required this.duration,
    required this.maxSpeed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStat(
          context,
          'Distance',
          '${distance.toStringAsFixed(1)} km',
          Icons.route,
        ),
        _buildStat(
          context,
          'Duration',
          _formatDuration(duration),
          Icons.timer,
        ),
        _buildStat(
          context,
          'Max Speed',
          '${maxSpeed.toStringAsFixed(1)} km/h',
          Icons.speed,
        ),
      ],
    );
  }

  Widget _buildStat(
      BuildContext context,
      String label,
      String value,
      IconData icon,
      ) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours h ${minutes} m';
    }
    return '$minutes min';
  }
}