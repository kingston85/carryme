import 'package:latlong2/latlong.dart';

/// Un-rounded distance calculator (latlong2 rounds results by default).
final Distance _distance = Distance(roundResult: false);

/// Straight-line distance between two points in kilometres.
double kmBetween(LatLng a, LatLng b) =>
    _distance.as(LengthUnit.Meter, a, b).toDouble() / 1000.0;
