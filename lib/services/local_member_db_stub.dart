import '../models/admin_models.dart';
import '../models/local_member.dart';

class LocalMemberDb {
  LocalMemberDb._();

  static final LocalMemberDb instance = LocalMemberDb._();

  Future<void> syncFromAdminUsers(List<AdminUser> users) async {}
  Future<List<LocalMember>> getMembers({bool includeDeleted = false}) async =>
      const [];
  Future<String> databasePath() async => '';
  Future<String> exportJsonSnapshot() async => '';

  Future<void> close() async {}
}
