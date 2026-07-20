import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();

  // Find start of _LiveGoogleMapSurface
  final startIdx = content.indexOf('class _LiveGoogleMapSurface extends StatefulWidget {');
  if (startIdx == -1) {
    print('Not found');
    return;
  }
  
  // Find end of _LiveGoogleMapSurfaceState
  // We'll search for the next class after _LiveGoogleMapSurfaceState
  final nextClassIdx = content.indexOf('class ', content.indexOf('class _LiveGoogleMapSurfaceState extends State<_LiveGoogleMapSurface> {') + 10);
  
  if (nextClassIdx != -1) {
    content = content.substring(0, startIdx) + content.substring(nextClassIdx);
    file.writeAsStringSync(content);
    print('Deleted old map widget from main.dart');
  }
}
