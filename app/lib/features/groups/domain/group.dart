/// Someone in a group. Ids are stable across groups, so the same friend in
/// two groups has one id.
final class Member {
  const Member(this.id, this.name);
  final String id;
  final String name;
}

final class Group {
  const Group({required this.id, required this.name, required this.members, this.detail = ''});

  final String id;
  final String name;
  final List<Member> members;

  /// Short context, e.g. "Lonavala" or "rent, wifi, groceries".
  final String detail;
}
