/// Someone in a group. Ids are stable across groups, so the same friend in
/// two groups has one id.
///
/// A member starts as a name typed by whoever made the group. Once a person
/// opens an invite and says "that's me", the member is linked to their
/// account ([userId]).
final class Member {
  const Member(this.id, this.name, {this.userId});
  final String id;
  final String name;

  /// The account that claimed this name; null until someone does.
  final String? userId;

  bool get claimed => userId != null;

  Member claimedBy(String uid) => Member(id, name, userId: uid);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'userId': userId};

  static Member fromJson(Map<String, Object?> json) =>
      Member(json['id']! as String, json['name']! as String, userId: json['userId'] as String?);
}

final class Group {
  const Group({required this.id, required this.name, required this.members, this.detail = '', this.createdAt});

  final String id;
  final String name;
  final List<Member> members;

  /// Short context, e.g. "Lonavala" or "rent, wifi, groceries".
  final String detail;
  final DateTime? createdAt;

  Member? memberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  Group copyWith({String? name, List<Member>? members, String? detail}) => Group(
    id: id,
    name: name ?? this.name,
    members: members ?? this.members,
    detail: detail ?? this.detail,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'detail': detail,
    'createdAt': createdAt?.toIso8601String(),
    'members': [for (final m in members) m.toJson()],
  };

  static Group fromJson(Map<String, Object?> json) => Group(
    id: json['id']! as String,
    name: json['name']! as String,
    detail: json['detail'] as String? ?? '',
    createdAt: switch (json['createdAt']) {
      final String s => DateTime.parse(s),
      _ => null,
    },
    members: [for (final m in json['members']! as List<Object?>) Member.fromJson((m! as Map).cast())],
  );
}
