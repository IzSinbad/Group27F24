
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:math' as math;
import '../models/trip.dart';
import '../services/pdf_service.dart';
import '../components/summary_stat_card.dart';
import 'dashboard_page.dart';

class TripSummaryPage extends StatefulWidget {
final Trip trip;

const TripSummaryPage({
Key? key,
required this.trip,
}) : super(key: key);

@override
State<TripSummaryPage> createState() => _TripSummaryPageState();
}

class _TripSummaryPageState extends State<TripSummaryPage> {

final MapController _mapController = MapController();
final _numberFormat = NumberFormat('#,##0.0');


bool _generatingPdf = false;
LatLngBounds? _mapBounds;

@override
void initState() {
super.initState();
_calculateMapBounds();
}


void _calculateMapBounds() {
if (widget.trip.routePoints.isEmpty) return;

double minLat = widget.trip.routePoints[0].latitude;
double maxLat = widget.trip.routePoints[0].latitude;
double minLng = widget.trip.routePoints[0].longitude;
double maxLng = widget.trip.routePoints[0].longitude;

// Find the minimum and maximum coordinates
for (var point in widget.trip.routePoints) {
minLat = math.min(minLat, point.latitude);
maxLat = math.max(maxLat, point.latitude);
minLng = math.min(minLng, point.longitude);
maxLng = math.max(maxLng, point.longitude);
}


const padding = 0.01; // Approximately 1km padding
_mapBounds = LatLngBounds(
LatLng(minLat - padding, minLng - padding),
LatLng(maxLat + padding, maxLng + padding),
);
}

// Fit the map to show the entire route
void _fitMapBounds() {
if (_mapBounds == null || !mounted) return;


final centerLat = (_mapBounds!.south + _mapBounds!.north) / 2;
final centerLng = (_mapBounds!.west + _mapBounds!.east) / 2;
final center = LatLng(centerLat, centerLng);

// Calculate and set appropriate zoom level
final zoom = _calculateZoomLevel(_mapBounds!);
_mapController.move(center, zoom);
}


double _calculateZoomLevel(LatLngBounds bounds) {
const minZoom = 1.0;
const maxZoom = 18.0;

final latDiff = bounds.north - bounds.south;
final lngDiff = bounds.east - bounds.west;
final maxDiff = math.max(latDiff, lngDiff);

// Calculate zoom level based on coordinate difference
final zoom = 15 - math.log(maxDiff * 111) / math.ln2;
return zoom.clamp(minZoom, maxZoom);
}


Future<void> _generateAndDownloadPDF() async {
if (_generatingPdf) return;

try {
setState(() => _generatingPdf = true);

final pdfService = PDFService();
final pdfFile = await pdfService.generateTripReport(widget.trip);

if (!mounted) return;

await Share.shareFiles(
[pdfFile.path],
text: 'Trip Report - ${DateFormat('MMM d, y').format(widget.trip.startTime)}',
);
} catch (e) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Error generating PDF: $e'),
backgroundColor: Colors.red,
),
);
} finally {
if (mounted) {
setState(() => _generatingPdf = false);
}
}
}

@override
Widget build(BuildContext context) {
final duration = widget.trip.endTime!.difference(widget.trip.startTime);
final theme = Theme.of(context);

return Scaffold(
appBar: AppBar(
title: const Text('Trip Summary'),
actions: [
IconButton(
icon: _generatingPdf
? const SizedBox(
width: 20,
height: 20,
child: CircularProgressIndicator(
strokeWidth: 2,
valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
),
)
    : const Icon(Icons.share),
onPressed: _generatingPdf ? null : _generateAndDownloadPDF,
tooltip: 'Download Trip Report',
),
],
),
body: SingleChildScrollView(
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [

if (widget.trip.routePoints.isNotEmpty) ...[
AspectRatio(
aspectRatio: 16 / 9,
child: FlutterMap(
mapController: _mapController,
options: MapOptions(
initialCenter: widget.trip.routePoints.first,
initialZoom: 15,
onMapReady: _fitMapBounds,
interactionOptions: const InteractionOptions(
enableScrollWheel: true,
enableMultiFingerGestureRace: true,
),
),
children: [
// Base map layer
TileLayer(
urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
userAgentPackageName: 'com.example.drive_tracker',
maxZoom: 19,
),

// Route line
PolylineLayer(
polylines: [
Polyline(
points: widget.trip.routePoints,
color: theme.primaryColor,
strokeWidth: 4.0,
),
],
),

// Start and end markers
MarkerLayer(
markers: [
// Start marker
Marker(
point: widget.trip.routePoints.first,
width: 80,
height: 80,
child: const Icon(
Icons.trip_origin,
color: Colors.green,
size: 30,
),
),
// End marker
Marker(
point: widget.trip.routePoints.last,
width: 80,
height: 80,
child: const Icon(
Icons.flag,
color: Colors.red,
size: 30,
),
),
],
),
],
),
),
],

// Trip statistics
Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Trip Statistics',
style: theme.textTheme.titleLarge?.copyWith(
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 16),
_buildStatisticsGrid(duration, theme),
],
),
),

// Speed warnings section
if (widget.trip.warnings.isNotEmpty)
_buildWarningsSection(theme),

// Download PDF button
Padding(
padding: const EdgeInsets.all(16.0),
child: ElevatedButton.icon(
onPressed: _generatingPdf ? null : _generateAndDownloadPDF,
icon: _generatingPdf
? const SizedBox(
width: 20,
height: 20,
child: CircularProgressIndicator(strokeWidth: 2),
)
    : const Icon(Icons.download),
style: ElevatedButton.styleFrom(
padding: const EdgeInsets.symmetric(vertical: 16),
minimumSize: const Size(double.infinity, 50),
),
label: Text(_generatingPdf ? 'Generating PDF...' : 'Download Trip Report'),
),
),
],
),
),
// Back to Dashboard button
bottomNavigationBar: SafeArea(
child: Padding(
padding: const EdgeInsets.all(16.0),
child: ElevatedButton(
onPressed: () => Navigator.pushAndRemoveUntil(
context,
MaterialPageRoute(builder: (_) => const DashboardPage()),
(route) => false,
),
style: ElevatedButton.styleFrom(
padding: const EdgeInsets.symmetric(vertical: 16),
),
child: const Text('Back to Dashboard'),
),
),
),
);
}

// Build the statistics grid showing trip metrics
Widget _buildStatisticsGrid(Duration duration, ThemeData theme) {
return Column(
children: [
Row(
children: [
Expanded(
child: SummaryStatCard(
icon: Icons.timeline,
label: 'Distance',
value: '${_numberFormat.format(widget.trip.distance)} km',
),
),
const SizedBox(width: 16),
Expanded(
child: SummaryStatCard(
icon: Icons.speed,
label: 'Avg Speed',
value: '${_numberFormat.format(widget.trip.averageSpeed)} km/h',
),
),
],
),
const SizedBox(height: 16),
Row(
children: [
Expanded(
child: SummaryStatCard(
icon: Icons.timer,
label: 'Duration',
value: _formatDuration(duration),
),
),
const SizedBox(width: 16),
Expanded(
child: SummaryStatCard(
icon: Icons.speed_outlined,
label: 'Max Speed',
value: '${_numberFormat.format(widget.trip.maxSpeed)} km/h',
),
),
],
),
],
);
}

// Build the warnings section showing speed violations
Widget _buildWarningsSection(ThemeData theme) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Padding(
padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
child: Text(
'Speed Warnings',
style: theme.textTheme.titleLarge?.copyWith(
fontWeight: FontWeight.bold,
),
),
),
ListView.builder(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
itemCount: widget.trip.warnings.length,
padding: const EdgeInsets.all(16),
itemBuilder: (context, index) {
final warning = widget.trip.warnings[index];
return Card(
color: theme.colorScheme.errorContainer,
child: ListTile(
leading: Icon(
Icons.warning_rounded,
color: theme.colorScheme.error,
),
title: Text(
'${_numberFormat.format(warning.speed)} km/h in a '
'${warning.speedLimit.toInt()} km/h zone',
),
subtitle: Text(
DateFormat('HH:mm:ss').format(warning.timestamp),
),
),
);
},
),
],
);
}

// Format duration for display
String _formatDuration(Duration duration) {
final hours = duration.inHours;
final minutes = duration.inMinutes.remainder(60);

if (hours > 0) {
return '$hours hr ${minutes} min';
}
return '$minutes min';
}

@override
void dispose() {
_mapController.dispose();
super.dispose();
}
}
