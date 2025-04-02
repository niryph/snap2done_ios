import 'dart:io';

void main() {
  final paths = [
    '/Volumes/SSD4TB/hakan/Desktop/snap2done_files/snap2done_main/snap2done_10/snap2done_ios/views',
    '/Volumes/SSD4TB/hakan/Desktop/snap2done_files/snap2done_main/snap2done_10/snap2done_ios/Views',
    '/Volumes/SSD4TB/hakan/Desktop/snap2done_files/snap2done_main/snap2done_10/snap2done_ios/views/landing_view.dart',
    '/Volumes/SSD4TB/hakan/Desktop/snap2done_files/snap2done_main/snap2done_10/snap2done_ios/Views/landing_view.dart',
  ];
  
  for (final path in paths) {
    final exists = File(path).existsSync() || Directory(path).existsSync();
    print('$path exists: $exists');
  }
}
