class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.roleId,
    this.estado,
    this.activo,
  });

  final int id;
  final String name;
  final String username;
  final int roleId;
  final String? estado;
  final int? activo;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: int.tryParse('${json['id'] ?? 0}') ?? 0,
    name: '${json['name'] ?? json['nombre'] ?? 'Motorizado'}',
    username: '${json['username'] ?? json['dni'] ?? ''}',
    roleId: int.tryParse('${json['role_id'] ?? 0}') ?? 0,
    estado: json['estado']?.toString(),
    activo: int.tryParse('${json['activo'] ?? ''}'),
  );
}
