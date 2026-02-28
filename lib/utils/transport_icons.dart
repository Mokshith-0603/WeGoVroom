import 'package:flutter/material.dart';

IconData vehicleTransportIcon(String? vehicle) {
  final v = (vehicle ?? '').trim().toLowerCase();
  if (v.contains('auto') || v.contains('rickshaw')) return Icons.electric_rickshaw;
  if (v.contains('shared cab') || v.contains('shared taxi')) return Icons.airport_shuttle;
  if (v.contains('cab') || v.contains('taxi')) return Icons.local_taxi;
  if (v.contains('mini bus') || v.contains('bus')) return Icons.directions_bus;
  if (v.contains('bike') || v.contains('scooter')) return Icons.two_wheeler;
  return Icons.directions_car;
}

IconData destinationTransportIcon(String? destination) {
  final d = (destination ?? '').trim().toLowerCase();
  if (d.contains('railway') || d.contains('train')) return Icons.train;
  if (d.contains('bus')) return Icons.directions_bus;
  if (d.contains('airport')) return Icons.flight_takeoff;
  if (d.contains('metro')) return Icons.directions_subway;
  if (d.contains('mall') || d.contains('shopping')) return Icons.local_mall;
  if (d.contains('city center') || d.contains('city centre') || d.contains('center')) {
    return Icons.location_city;
  }
  if (d.contains('college') || d.contains('campus') || d.contains('university')) {
    return Icons.school;
  }
  return Icons.place_outlined;
}
