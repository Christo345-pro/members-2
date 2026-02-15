import '../models/admin_models.dart';

class LocalMemberDb {
  LocalMemberDb._();

  static final LocalMemberDb instance = LocalMemberDb._();

  Future<void> syncFromAdminUsers(List<AdminUser> users) async {}

  Future<void> close() async {}
}
