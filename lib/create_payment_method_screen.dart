import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'utils.dart';

class CreatePaymentMethodScreen extends StatefulWidget {
  const CreatePaymentMethodScreen({
    super.key,
    required this.accessToken,
    this.paymentMethod,
  });

  final String accessToken;
  final Map<String, dynamic>? paymentMethod;

  @override
  State<CreatePaymentMethodScreen> createState() =>
      _CreatePaymentMethodScreenState();
}

class _CreatePaymentMethodScreenState extends State<CreatePaymentMethodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _paymentNameController = TextEditingController();
  final _referenceTokenController = TextEditingController();
  final _last4Controller = TextEditingController();
  final _expirationMonthController = TextEditingController();
  final _expirationYearController = TextEditingController();
  bool _isDefault = false;
  bool _isLoading = false;

  String _selectedType = 'tarjeta_credito';
  late int _paymentMethodId;

  bool get _isEditing => widget.paymentMethod != null;

  int? _parseNumericId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) {
      final asInt = int.tryParse(value.trim());
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(value.trim());
      if (asDouble != null) return asDouble.toInt();
      return null;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final method = widget.paymentMethod!;
      _paymentMethodId = _parseNumericId(method['id']) ?? 0;
      _selectedType = method['tipo']?.toString() ?? 'tarjeta_credito';
      _paymentNameController.text =
          method['payment_name']?.toString() ?? method['nombre']?.toString() ?? '';
      _referenceTokenController.text =
          method['referencia_token']?.toString() ?? '';
      _last4Controller.text = method['last4']?.toString() ?? '';
      _expirationMonthController.text =
          method['mes_expiracion']?.toString() ?? '';
      _expirationYearController.text =
          method['anio_expiracion']?.toString() ?? '';
      final predeterminado = method['predeterminado'];
      _isDefault = predeterminado is bool
          ? predeterminado
          : predeterminado?.toString().toLowerCase() == 'true';
    }
  }

  bool _isPaymentDefault(Map<String, dynamic> method) {
    final val =
        method['predeterminado'] ?? method['predet'] ?? method['default'];
    if (val == null) return false;
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return false;
  }

  Future<bool> _checkExistingDefault() async {
    final uri = Uri.parse(
      'https://exrydayuvwxrapejnawg.supabase.co/functions/v1/listar-metodos-pago',
    );
    final payload = {'access_token': widget.accessToken};

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) return false;

      final responseBody = jsonDecode(response.body);
      List<dynamic>? methodsRaw;

      if (responseBody is List) {
        methodsRaw = responseBody;
      } else if (responseBody is Map) {
        methodsRaw =
            responseBody['metodos'] ??
            responseBody['metodos_pago'] ??
            responseBody['metodosPago'];
      }

      if (methodsRaw == null) return false;

      for (final method in methodsRaw.whereType<Map<String, dynamic>>()) {
        if (_isPaymentDefault(method)) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _submitPaymentMethod() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isDefault && !_isEditing) {
      final hasExistingDefault = await _checkExistingDefault();
      if (hasExistingDefault && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('defaultPaymentMethod')),
            content: Text(
              languageNotifier.value == 'es'
                  ? 'Ya existe un método de pago predeterminado. Solo puede haber un método predeterminado a la vez.'
                  : 'A default payment method already exists. Only one payment method can be default at a time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('cancel')),
              ),
            ],
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse(
      _isEditing
          ? 'https://exrydayuvwxrapejnawg.supabase.co/functions/v1/editar-metodo-pago'
          : 'https://exrydayuvwxrapejnawg.supabase.co/functions/v1/crear-metodo-pago-generico',
    );
    final payload = {
      'access_token': widget.accessToken,
      if (_isEditing) 'id': _paymentMethodId,
      'tipo': _selectedType,
      if (_paymentNameController.text.trim().isNotEmpty)
        'payment_name': _paymentNameController.text.trim(),
      if (_referenceTokenController.text.trim().isNotEmpty)
        'referencia_token': _referenceTokenController.text.trim(),
      if (_last4Controller.text.trim().isNotEmpty)
        'last4': _last4Controller.text.trim(),
      if (_expirationMonthController.text.trim().isNotEmpty)
        'mes_expiracion': _expirationMonthController.text.trim(),
      if (_expirationYearController.text.trim().isNotEmpty)
        'anio_expiracion': _expirationYearController.text.trim(),
      'predeterminado': _isDefault,
    };

    try {
      final response = _isEditing
          ? await http.patch(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer ${widget.accessToken}',
              },
              body: jsonEncode(payload),
            )
          : await http.post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer ${widget.accessToken}',
              },
              body: jsonEncode(payload),
            );

      if (!mounted) return;

      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200 &&
          responseBody is Map &&
          responseBody['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? tr('editSuccess') : tr('paymentMethodCreated'),
            ),
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }

      final errorMessage = responseBody is Map && responseBody['error'] != null
          ? responseBody['error'].toString()
          : tr('loginError', {
              'statusCode': response.statusCode.toString(),
              'errorMessage': responseBody.toString(),
            });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
        ),
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

  @override
  void dispose() {
    _paymentNameController.dispose();
    _referenceTokenController.dispose();
    _last4Controller.dispose();
    _expirationMonthController.dispose();
    _expirationYearController.dispose();
    super.dispose();
  }

  String _paymentMethodTypeLabel(String type) {
    switch (type) {
      case 'tarjeta_credito':
        return tr('creditCard');
      case 'tarjeta_debito':
        return tr('debitCard');
      case 'paypal':
        return tr('paypal');
      case 'transferencia_bancaria':
        return tr('bankTransfer');
      case 'otro':
      default:
        return tr('other');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? tr('editPaymentMethod') : tr('createPaymentMethod'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isEditing
                          ? tr('editPaymentMethod')
                          : tr('createPaymentMethod'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: InputDecoration(
                        labelText: tr('paymentMethodType'),
                      ),
                      items:
                          [
                                'tarjeta_credito',
                                'tarjeta_debito',
                                'paypal',
                                'transferencia_bancaria',
                                'otro',
                              ]
                              .map(
                                (type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(_paymentMethodTypeLabel(type)),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _paymentNameController,
                      decoration: InputDecoration(
                        labelText: tr('paymentMethodName'),
                        hintText: tr('paymentMethodNameHint'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _referenceTokenController,
                      decoration: InputDecoration(
                        labelText: tr('referenceToken'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _last4Controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr('last4')),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        if (value.trim().length != 4) {
                          return tr('last4Invalid');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expirationMonthController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: tr('expirationMonth'),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              final month = int.tryParse(value.trim());
                              if (month == null || month < 1 || month > 12) {
                                return tr('expirationMonthInvalid');
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _expirationYearController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: tr('expirationYear'),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              final year = int.tryParse(value.trim());
                              if (year == null || year < 2024) {
                                return tr('expirationYearInvalid');
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(tr('defaultPaymentMethod')),
                      value: _isDefault,
                      onChanged: (value) {
                        setState(() {
                          _isDefault = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton.tonal(
                      onPressed: _isLoading ? null : _submitPaymentMethod,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isEditing
                                  ? tr('editPaymentMethod')
                                  : tr('createPaymentMethod'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}