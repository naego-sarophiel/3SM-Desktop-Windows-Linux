import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'utils.dart';
import 'subscriptions_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _regionController = TextEditingController(text: 'es-ES');
  final _timezoneController = TextEditingController(text: 'Europe/Madrid');
  bool _isRegistering = false;
  bool _isObscured = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isCheckingSavedToken = true;

  @override
  void initState() {
    super.initState();
    _checkSavedToken();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _regionController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _checkSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('access_token');
    if (savedToken == null) {
      if (mounted) {
        setState(() {
          _isCheckingSavedToken = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse(
      'https://exrydayuvwxrapejnawg.supabase.co/functions/v1/mis-suscripciones',
    );
    final payload = {'access_token': savedToken};

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $savedToken',
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200 &&
          responseBody is Map &&
          responseBody['ok'] == true) {
        final usuario = (responseBody['usuario'] as Map<dynamic, dynamic>?)
            ?.cast<String, dynamic>();
        final displayName =
            usuario?['nombre']?.toString() ??
            usuario?['correo']?.toString() ??
            tr('appTitle');
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SubscriptionsScreen(
              accessToken: savedToken,
              displayName: displayName,
            ),
          ),
        );
        return;
      }

      await clearSavedToken();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('sessionClosed')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('networkError', {'error': error.toString()})),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSavedToken = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (_isRegistering) {
      await _handleRegister();
    } else {
      await _handleLogin();
    }
  }

  Future<void> _handleRegister() async {
    final uri = Uri.parse(
      'https://exrydayuvwxrapejnawg.supabase.co/functions/v1/create-usuario',
    );
    final payload = {
      'nombre': _nameController.text.trim(),
      'correo': _emailController.text.trim(),
      'password': _passwordController.text,
      'configuracion_regional': _regionController.text.trim(),
      'zona_horaria': _timezoneController.text.trim(),
    };

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
          'apikey': supabaseAnonKey,
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('registerSuccess'))),
        );
        setState(() {
          _isRegistering = false;
        });
        return;
      }

      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody is Map && responseBody['error'] != null
          ? responseBody['error'].toString()
          : response.body;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('networkError', {'error': error.toString()})), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (supabaseAnonKey.startsWith('<') || supabaseAnonKey.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('supabaseNotConfigured')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(
      'https://exrydayuvwxrapejnawg.supabase.co/functions/v1/login-usuario',
    );
    final payload = {
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
    };

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
          'apikey': supabaseAnonKey,
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      dynamic responseBody;
      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {
        responseBody = {'error': response.body};
      }

      String? accessToken;
      String? userName;
      String? userEmail;
      if (responseBody is Map) {
        accessToken =
            responseBody['access_token']?.toString() ??
            responseBody['session']?['access_token']?.toString();
        userEmail =
            responseBody['user']?['email']?.toString() ??
            responseBody['session']?['user']?['email']?.toString();
        userName =
            responseBody['user']?['user_metadata']?['nombre']?.toString() ??
            responseBody['session']?['user']?['user_metadata']?['nombre']
                ?.toString();
      }

      if (response.statusCode == 200 && accessToken != null) {
        final token = accessToken;
        if (_rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', token);
        } else {
          await clearSavedToken();
        }

        if (!mounted) return;
        final displayName =
            userName ?? userEmail ?? _emailController.text.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('loginSuccess', {'displayName': displayName})),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SubscriptionsScreen(
              accessToken: token,
              displayName: displayName,
            ),
          ),
        );
        return;
      }

      final errorMessage = responseBody is Map && responseBody['error'] != null
          ? responseBody['error'].toString()
          : response.body;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('loginError', {
              'statusCode': response.statusCode.toString(),
              'errorMessage': errorMessage,
            }),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      debugPrint(
        'Inicio de sesion fallido: status=${response.statusCode}, body=${response.body}',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('networkError', {'error': error.toString()})),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return tr('emailRequired');
    }
    final email = value.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return tr('invalidEmail');
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return tr('passwordRequired');
    }
    if (value.length < 6) {
      return tr('passwordMinLength');
    }
    return null;
  }

  String? _validateRequired(String? value, String errorKey) {
    if (value == null || value.trim().isEmpty) {
      return tr(errorKey);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSavedToken) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isRegistering ? tr('signUp') : tr('welcomeBack'),
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRegistering ? tr('registerInstructions') : tr('loginInstructions'),
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      if (_isRegistering) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: tr('nameLabel'),
                            prefixIcon: const Icon(Icons.person),
                          ),
                          validator: (v) => _validateRequired(v, 'nameRequired'),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: tr('emailLabel'),
                          prefixIcon: const Icon(Icons.email),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _isObscured,
                        decoration: InputDecoration(
                          labelText: tr('passwordLabel'),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isObscured
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isObscured = !_isObscured;
                              });
                            },
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 12),
                      if (_isRegistering) ...[
                        TextFormField(
                          controller: _regionController,
                          decoration: InputDecoration(
                            labelText: tr('regionLabel'),
                            prefixIcon: const Icon(Icons.language),
                          ),
                          validator: (v) => _validateRequired(v, 'regionRequired'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _timezoneController,
                          decoration: InputDecoration(
                            labelText: tr('timezoneLabel'),
                            prefixIcon: const Icon(Icons.schedule),
                          ),
                          validator: (v) => _validateRequired(v, 'timezoneRequired'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!_isRegistering)
                        CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('rememberMe')),
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_isRegistering ? tr('createAccount') : tr('signIn')),
                      ),
                      const SizedBox(height: 16),
                      if (!_isRegistering)
                        TextButton(
                          onPressed: () {},
                          child: Text(tr('forgotPassword')),
                        ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isRegistering = !_isRegistering;
                          });
                        },
                        child: Text(_isRegistering ? tr('alreadyHaveAccount') : tr('noAccount')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
