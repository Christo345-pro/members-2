class LocalMember {
  final int? serverId;
  final String name;
  final String surname;
  final String email;
  final String? accountNr;
  final DateTime updatedAt;
  final bool appAndroid;
  final bool appWindows;
  final bool appWeb;
  final bool isLocalOnly;
  final bool isDeleted;

  const LocalMember({
    this.serverId,
    required this.name,
    required this.surname,
    required this.email,
    this.accountNr,
    required this.updatedAt,
    this.appAndroid = false,
    this.appWindows = false,
    this.appWeb = false,
    this.isLocalOnly = false,
    this.isDeleted = false,
  });

  LocalMember copyWith({
    int? serverId,
    String? name,
    String? surname,
    String? email,
    String? accountNr,
    DateTime? updatedAt,
    bool? appAndroid,
    bool? appWindows,
    bool? appWeb,
    bool? isLocalOnly,
    bool? isDeleted,
  }) {
    return LocalMember(
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      email: email ?? this.email,
      accountNr: accountNr ?? this.accountNr,
      updatedAt: updatedAt ?? this.updatedAt,
      appAndroid: appAndroid ?? this.appAndroid,
      appWindows: appWindows ?? this.appWindows,
      appWeb: appWeb ?? this.appWeb,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'server_id': serverId,
      'name': name,
      'surname': surname,
      'email': email,
      'account_nr': accountNr,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'app_android': appAndroid ? 1 : 0,
      'app_windows': appWindows ? 1 : 0,
      'app_web': appWeb ? 1 : 0,
      'is_local_only': isLocalOnly ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'surname': surname,
      'email': email,
      'account_nr': accountNr ?? '',
      'app_android': appAndroid,
      'app_windows': appWindows,
      'app_web': appWeb,
    };
  }

  factory LocalMember.fromMap(Map<String, dynamic> map) {
    return LocalMember(
      serverId: map['server_id'] as int?,
      name: (map['name'] ?? '').toString(),
      surname: (map['surname'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      accountNr: map['account_nr']?.toString(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] ?? 0) as int,
      ),
      appAndroid: (map['app_android'] ?? 0) == 1,
      appWindows: (map['app_windows'] ?? 0) == 1,
      appWeb: (map['app_web'] ?? 0) == 1,
      isLocalOnly: (map['is_local_only'] ?? 0) == 1,
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }
}
