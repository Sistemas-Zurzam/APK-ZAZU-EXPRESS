import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../state/providers.dart';

class RegisterDriverScreen extends ConsumerStatefulWidget {
  const RegisterDriverScreen({super.key});

  @override
  ConsumerState<RegisterDriverScreen> createState() =>
      _RegisterDriverScreenState();
}

class _RegisterDriverScreenState extends ConsumerState<RegisterDriverScreen> {
  final name = TextEditingController();
  final dni = TextEditingController();
  final phone = TextEditingController();
  final license = TextEditingController();
  final plate = TextEditingController();
  final password = TextEditingController();
  final passwordConfirmation = TextEditingController();
  String vehicleType = 'propio';
  bool loading = false;
  bool visible = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    dni.dispose();
    phone.dispose();
    license.dispose();
    plate.dispose();
    password.dispose();
    passwordConfirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cleanName = name.text.trim();
    final cleanDni = dni.text.trim();
    final cleanPhone = phone.text.trim();
    if (cleanName.isEmpty || cleanDni.isEmpty || cleanPhone.isEmpty) {
      setState(() => error = 'Completa nombre, DNI y telefono.');
      return;
    }
    if (!RegExp(r'^\d{8}$').hasMatch(cleanDni)) {
      setState(() => error = 'El DNI debe tener exactamente 8 numeros.');
      return;
    }
    if (license.text.trim().isEmpty || plate.text.trim().isEmpty) {
      setState(() => error = 'Completa licencia y placa.');
      return;
    }
    if (password.text.length < 8 || !RegExp(r'\d').hasMatch(password.text)) {
      setState(
        () => error =
            'La contrasena debe tener 8 caracteres y al menos 1 numero.',
      );
      return;
    }
    if (password.text != passwordConfirmation.text) {
      setState(() => error = 'Las contrasenas no coinciden.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await ref.read(apiProvider).registerDriver({
        'nombre': cleanName,
        'dni': cleanDni,
        'telefono': cleanPhone,
        'licencia': license.text.trim(),
        'placa': plate.text.trim().toUpperCase(),
        'vehiculo_tipo': vehicleType,
        'password': password.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro enviado. Ya puedes intentar iniciar sesion.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = _message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _message(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final serverMessage = _serverMessage(data);
      if (serverMessage != null) return serverMessage;
      final statusCode = e.response?.statusCode;
      if (statusCode == 422) return 'Revisa los datos del registro.';
      if (statusCode == 500) {
        return 'El servidor no pudo registrar el usuario. Prueba otra vez o revisa la API.';
      }
      if (statusCode != null) return 'No se pudo registrar. Error $statusCode.';
      return 'No se pudo conectar con el servidor.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  String? _serverMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
      final errors = data['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString();
          }
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear usuario')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Registro de motorizado',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea tu acceso para usar la APK.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: dni,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'DNI / usuario',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefono',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: license,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Licencia',
                      prefixIcon: Icon(Icons.credit_card_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: plate,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Placa',
                      prefixIcon: Icon(Icons.two_wheeler_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'propio', label: Text('Propio')),
                      ButtonSegment(value: 'empresa', label: Text('Empresa')),
                    ],
                    selected: {vehicleType},
                    onSelectionChanged: loading
                        ? null
                        : (values) =>
                              setState(() => vehicleType = values.first),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: !visible,
                    decoration: InputDecoration(
                      labelText: 'Contrasena',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => visible = !visible),
                        icon: Icon(
                          visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordConfirmation,
                    obscureText: !visible,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contrasena',
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crear usuario'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
