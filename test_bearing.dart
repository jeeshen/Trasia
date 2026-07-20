import 'package:geolocator/geolocator.dart';

void main() {
  final bearing = Geolocator.bearingBetween(1.0, 1.0, 1.0, 1.0);
  print('Bearing is: $bearing');
}
