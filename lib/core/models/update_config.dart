class UpdateConfig {
  final String latestVersion;
  final String? apiBaseUrl;
  final Map<String, String> downloads;
  final List<String> updateNotes;
  final SupportConfig? support;

  const UpdateConfig({
    required this.latestVersion,
    required this.apiBaseUrl,
    required this.downloads,
    required this.updateNotes,
    required this.support,
  });

  factory UpdateConfig.fromJson(Map<String, dynamic> json) {
    final latestVersion = (json['latest_version'] ?? '').toString().trim();

    String? apiBaseUrl;
    final apiObject = json['api'];
    if (apiObject is Map<String, dynamic>) {
      final value = apiObject['base_url']?.toString().trim();
      if (value != null && value.isNotEmpty) {
        apiBaseUrl = value;
      }
    }

    final downloads = <String, String>{};
    final downloadsObject = json['downloads'];
    if (downloadsObject is Map<String, dynamic>) {
      for (final entry in downloadsObject.entries) {
        final url = entry.value.toString().trim();
        if (url.isNotEmpty) {
          downloads[entry.key] = url;
        }
      }
    }

    // Backward compatibility with old flat download_url field.
    final legacyDownloadUrl = json['download_url']?.toString().trim();
    if ((legacyDownloadUrl ?? '').isNotEmpty && !downloads.containsKey('default')) {
      downloads['default'] = legacyDownloadUrl!;
    }

    final updateNotes = <String>[];
    final notesObject = json['update_notes'];
    if (notesObject is List) {
      for (final note in notesObject) {
        final text = note.toString().trim();
        if (text.isNotEmpty) {
          updateNotes.add(text);
        }
      }
    } else if (notesObject is String && notesObject.trim().isNotEmpty) {
      updateNotes.add(notesObject.trim());
    }

    SupportConfig? support;
    final supportObject = json['support'];
    if (supportObject is Map<String, dynamic>) {
      support = SupportConfig.fromJson(supportObject);
    }

    return UpdateConfig(
      latestVersion: latestVersion,
      apiBaseUrl: apiBaseUrl,
      downloads: downloads,
      updateNotes: updateNotes,
      support: support,
    );
  }
}

class SupportConfig {
  final String? email;
  final String? telegram;
  final String? whatsapp;

  const SupportConfig({
    required this.email,
    required this.telegram,
    required this.whatsapp,
  });

  factory SupportConfig.fromJson(Map<String, dynamic> json) {
    String? read(String key) {
      final value = json[key]?.toString().trim();
      if (value == null || value.isEmpty) return null;
      return value;
    }

    return SupportConfig(
      email: read('email'),
      telegram: read('telegram'),
      whatsapp: read('whatsapp'),
    );
  }
}

