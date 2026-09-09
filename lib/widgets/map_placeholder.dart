import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/app_colors.dart';
import '../models/report_item.dart';

/// Nearby Items Map widget supporting both Google Maps and a styled fallback.
///
/// Currently unused — the dashboard's map section was removed — but kept wired to real data so
/// re-enabling it does not resurrect invented markers. Pass the reports to plot; those without
/// coordinates are skipped.
///
/// To enable live Google Maps:
/// 1. Add your Google Maps API key to AndroidManifest.xml & Info.plist.
/// 2. Set [useLiveGoogleMap] to `true`.
class MapPlaceholderWidget extends StatefulWidget {
  final bool useLiveGoogleMap;
  final List<ReportItem> reports;

  const MapPlaceholderWidget({
    super.key,
    this.useLiveGoogleMap = false,
    this.reports = const [],
  });

  @override
  State<MapPlaceholderWidget> createState() => _MapPlaceholderWidgetState();
}

class _MapPlaceholderWidgetState extends State<MapPlaceholderWidget> {
  /// Fallback only — used when no report carries coordinates.
  static const LatLng _fallbackCenter = LatLng(6.9271, 79.8612); // Colombo

  Iterable<ReportItem> get _located =>
      widget.reports.where((r) => r.lat != null && r.lng != null);

  /// Centres on the first located report, so the map opens where the items actually are.
  LatLng get _center {
    final first = _located.isEmpty ? null : _located.first;
    return first == null ? _fallbackCenter : LatLng(first.lat!, first.lng!);
  }

  Set<Marker> get _markers => _located
      .map(
        (r) => Marker(
          markerId: MarkerId(r.id),
          position: LatLng(r.lat!, r.lng!),
          infoWindow: InfoWindow(title: r.title, snippet: r.location),
        ),
      )
      .toSet();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (widget.useLiveGoogleMap)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _center,
                  zoom: 14.0,
                ),
                markers: _markers,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
              )
            else
              // High-fidelity graphic map visual matching source design
              CustomPaint(
                size: const Size(double.infinity, 150),
                painter: MapPainter(),
              ),

            // Map Pins Overlay for mockup
            if (!widget.useLiveGoogleMap) ...[
              const Positioned(
                top: 35,
                left: 70,
                child: _MapPinBadge(color: Color(0xFFF43F5E), icon: Icons.location_on),
              ),
              const Positioned(
                top: 25,
                right: 75,
                child: _MapPinBadge(color: Color(0xFFF59E0B), icon: Icons.location_on),
              ),
              const Positioned(
                bottom: 35,
                left: 170,
                child: _MapPinBadge(color: Color(0xFF10B981), icon: Icons.location_on),
              ),
              // User current location pulsing ring
              Positioned(
                top: 55,
                left: 155,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1D4ED8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Floating Chip Badge (📍 3 items within 1km)
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📍 ', style: TextStyle(fontSize: 10)),
                    Text(
                      '3 items within 1km',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPinBadge extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapPinBadge({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(100),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }
}

class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFE5EDFB);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    // Horizontal roads
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.35), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.72), Offset(size.width, size.height * 0.72), roadPaint);

    // Vertical roads
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.68, 0), Offset(size.width * 0.68, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
