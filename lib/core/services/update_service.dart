import 'dart:convert';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String version;
  final String downloadUrl;

  UpdateInfo(this.version, this.downloadUrl);
}

class UpdateService {
  final String versionJsonUrl =
      "https://drive.google.com/uc?export=download&id=1aMv_VNEFff1XzQeiG80s0aEL4r5_c9ao";

  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final response = await http.get(Uri.parse(versionJsonUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final latest = data["latest_version"];
        final url = data["download_url"];

        if (latest != null && url != null) {
          if (_isNewerVersion(currentVersion, latest)) {
            return UpdateInfo(latest, url);
          }
        }
      }
    } catch (e) {
      print("Update check error: $e");
    }

    return null;
  }

  bool _isNewerVersion(String current, String latest) {
    final c = current.split('.').map(int.parse).toList();
    final l = latest.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }
}
