import 'dart:io';

void main() async {
  // Try to create symbolic link from Views to views
  // This is a one-time fix you should run separately
  try {
    final viewsDir = Directory('/Volumes/SSD4TB/hakan/Desktop/snap2done_files/snap2done_main/snap2done_10/snap2done_ios/views');
    final viewsDirUpper = Directory('/Volumes/SSD4TB/hakan/Desktop/snap2done_files/snap2done_main/snap2done_10/snap2done_ios/Views');
    
    if (!viewsDir.existsSync()) {
      await viewsDir.create();
      print('Created views directory');
    }
    
    if (!viewsDirUpper.existsSync()) {
      // Create symbolic link - run this on command line if this code doesn't work:
      // ln -s /Volumes/SSD4TB/.../views /Volumes/SSD4TB/.../Views
      print('Run this command to create a symbolic link:');
      print('ln -s "${viewsDir.path}" "${viewsDirUpper.path}"');
    }
  } catch (e) {
    print('Error creating symbolic link: $e');
  }
}
