import 'package:permission_handler/permission_handler.dart';

Future<bool> requestCamera() async {
  final status = await Permission.camera.request();
  return status.isGranted;
}
