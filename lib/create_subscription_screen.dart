import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'utils.dart';

class CreateSubscriptionScreen extends StatefulWidget {
  const CreateSubscriptionScreen({
    super.key,
    required this.accessToken,
    this.subscription,
  });

  final String accessToken;
  final Map<String, dynamic>? subscription;

  @override
  State<CreateSubscriptionScreen> createState() =>
      _CreateSubscriptionScreenState();
}

class _CreateSubscriptionScreenState extends State<CreateSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceController = TextEditingController();
  final _costController = TextEditingController();
  final _currencyController = TextEditingController(text: 'EUR');
  final _cycleController = TextEditingController(text: 'mensual');
  final _chargeDateController = TextEditingController();
  final _nextChargeDateController = TextEditingController();
  final _trialEndController = TextEditingController();
  final _statusController = TextEditingController(text: 'activa');
  final _cancelUrlController = TextEditingController();
  bool _isLoading = false;

  late int _selectedCategoryId;

  bool get _isEditing => widget.subscription != null;

  int? _selectedPaymentMethodId;
  List<Map<String, dynamic>> _paymentMethods = [];

  int? _parseNumericId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) {
      final cleaned = value.trim();
      final asInt = int.tryParse(cleaned);
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(cleaned);
      if (asDouble != null) return asDouble.toInt();
      return null;
    }
    if (value is Map) {
      try {
        final s = value.values.first.toString();
        return _parseNumericId(s);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _paymentMethodShortLabel(String? tipo) {
    final t = tipo?.toString().toLowerCase() ?? '';
    if (t.contains('credito') ||
        t.contains('tarjeta_credito') ||
        t.contains('credit')) {
      return 'credito';
    }
    if (t.contains('debito') ||
        t.contains('tarjeta_debito') ||
        t.contains('debit')) {
      return 'debito';
    }
    return t.isEmpty ? tr('unknown') : t;
  }

  bool _isPaymentDefault(Map<String, dynamic> method) {
    final val =
        method['predeterminado'] ?? method['predet'] ?? method['default'];
    if (val == null) return false;
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return false;
  }

  int? get _subscriptionId =>
      _parseNumericId(widget.subscription?['id_suscripcion']) ??
      _parseNumericId(widget.subscription?['id']);

  static const List<Map<String, dynamic>> _categories = [
    {'id': 1, 'nombre': 'Streaming', 'icon': 'play-circle', 'color': '#E50914'},
    {'id': 2, 'nombre': 'Música', 'icon': 'music', 'color': '#1DB954'},
    {
      'id': 3,
      'nombre': 'Productividad',
      'icon': 'briefcase',
      'color': '#0078D4',
    },
    {'id': 4, 'nombre': 'Gaming', 'icon': 'gamepad', 'color': '#9B59B6'},
    {'id': 5, 'nombre': 'Noticias', 'icon': 'newspaper', 'color': '#F39C12'},
    {'id': 6, 'nombre': 'Software', 'icon': 'code', 'color': '#2ECC71'},
    {'id': 7, 'nombre': 'Salud', 'icon': 'heart', 'color': '#E74C3C'},
    {'id': 8, 'nombre': 'Educación', 'icon': 'book', 'color': '#3498DB'},
    {'id': 9, 'nombre': 'Otros', 'icon': 'Etiqueta', 'color': '#95A5A6'},
  ];

  int _parseCategoryId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 1;
    return 1;
  }

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = _parseCategoryId(
      widget.subscription?['id_categoria'],
    );
    _selectedPaymentMethodId =
        _parseNumericId(widget.subscription?['id_payment_method']) ??
        _parseNumericId(widget.subscription?['id_metodo_pago']) ??
        _parseNumericId(widget.subscription?['idMetodoPago']);
    _loadPaymentMethods();
    if (_isEditing) {
      final subscription = widget.subscription!;
      _serviceController.text =
          subscription['nombre_servicio']?.toString() ?? '';
      _costController.text = subscription['costo_mensual']?.toString() ?? '';
      _currencyController.text =
          subscription['moneda']?.toString() ?? _currencyController.text;
      _cycleController.text =
          subscription['ciclo_facturacion']?.toString() ??
          _cycleController.text;
      _chargeDateController.text =
          subscription['fecha_cobro']?.toString() ?? '';
      _nextChargeDateController.text =
          subscription['proxima_fecha_cobro']?.toString() ?? '';
      _trialEndController.text =
          subscription['fecha_fin_prueba']?.toString() ?? '';
      _statusController.text =
          subscription['estado']?.toString() ?? _statusController.text;
      _cancelUrlController.text =
          subscription['url_cancelacion']?.toString() ?? '';
    }
  }

  Future<void> _loadPaymentMethods() async {
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

      if (!mounted) return;

      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        List<dynamic>? methodsRaw;
        if (responseBody is List) {
          methodsRaw = responseBody;
        } else if (responseBody is Map) {
          if (responseBody['metodos'] is List) {
            methodsRaw = responseBody['metodos'] as List<dynamic>;
          } else if (responseBody['metodos_pago'] is List) {
            methodsRaw = responseBody['metodos_pago'] as List<dynamic>;
          } else if (responseBody['metodosPago'] is List) {
            methodsRaw = responseBody['metodosPago'] as List<dynamic>;
          }
        }

        setState(() {
          _paymentMethods = (methodsRaw ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          if (_selectedPaymentMethodId == null && _paymentMethods.isNotEmpty) {
            _selectedPaymentMethodId =
                _parseNumericId(_paymentMethods.first['id_payment_method']) ??
                _parseNumericId(_paymentMethods.first['id']) ??
                _parseNumericId(_paymentMethods.first['id_metodo_pago']) ??
                _parseNumericId(_paymentMethods.first['idMetodoPago']);
          }
        });
        return;
      }
    } catch (e) {
      debugPrint('[_loadPaymentMethods] EXCEPTION: $e');
    }
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _costController.dispose();
    _currencyController.dispose();
    _cycleController.dispose();
    _chargeDateController.dispose();
    _nextChargeDateController.dispose();
    _trialEndController.dispose();
    _statusController.dispose();
    _cancelUrlController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toString().split(' ')[0];
      });
    }
  }

  Future<void> _submitSubscription() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse(
      _isEditing
          ? 'https://exrydayuvwxrapejnawg.supabase.co/functions/v1/editar-suscripcion'
          : 'https://exrydayuvwxrapejnawg.supabase.co/functions/v1/crear-suscripcion',
    );

    final payload = {
      'access_token': widget.accessToken,
      if (_isEditing && _subscriptionId != null)
        'id_suscripcion': _subscriptionId,
      if (_selectedPaymentMethodId != null)
        'id_payment_method': _selectedPaymentMethodId,
      'nombre_servicio': _serviceController.text.trim(),
      'costo_mensual': double.tryParse(_costController.text.trim()) ?? 0,
      'moneda': _currencyController.text.trim(),
      'ciclo_facturacion': _cycleController.text.trim(),
      'fecha_cobro': _chargeDateController.text.trim(),
      'proxima_fecha_cobro': _nextChargeDateController.text.trim(),
      'fecha_fin_prueba': _trialEndController.text.trim().isEmpty
          ? null
          : _trialEndController.text.trim(),
      'estado': _statusController.text.trim(),
      'url_cancelacion': _cancelUrlController.text.trim(),
      'id_categoria': _selectedCategoryId,
      'categorias': {
        'id': _selectedCategoryId,
        'icon': _categories.firstWhere(
          (cat) => cat['id'] == _selectedCategoryId,
        )['icon'],
        'color': _categories.firstWhere(
          (cat) => cat['id'] == _selectedCategoryId,
        )['color'],
        'nombre': _categories.firstWhere(
          (cat) => cat['id'] == _selectedCategoryId,
        )['nombre'],
      },
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
              _isEditing ? tr('editSuccess') : tr('subscriptionCreated'),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? tr('editSubscription') : tr('newSubscription'),
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
                          ? tr('editSubscription')
                          : tr('addSubscription'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _serviceController,
                      decoration: InputDecoration(
                        labelText: tr('serviceLabel'),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? tr('serviceRequired')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr('monthlyCost')),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return tr('costRequired');
                        }
                        if (double.tryParse(value.trim()) == null) {
                          return tr('invalidNumber');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _currencyController.text.isEmpty ? null : _currencyController.text,
                      decoration: InputDecoration(
                        labelText: tr('currencyLabel'),
                      ),
                      items: ['USD', 'EUR', 'GBP', 'JPY', 'INR']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) => setState(() => _currencyController.text = val!),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? tr('currencyRequired')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _cycleController.text.toLowerCase(),
                      decoration: InputDecoration(
                        labelText: tr('billingCycle'),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                        DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                        DropdownMenuItem(value: 'anual', child: Text('Anual')),
                      ],
                      onChanged: (val) => setState(() => _cycleController.text = val!),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? tr('billingCycleRequired')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _chargeDateController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: tr('chargeDate')),
                      onTap: () => _selectDate(context, _chargeDateController),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? tr('chargeDateRequired')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nextChargeDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: tr('nextChargeDate'),
                      ),
                      onTap: () => _selectDate(context, _nextChargeDateController),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? tr('nextChargeDateRequired')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _trialEndController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: tr('trialEnd')),
                      onTap: () => _selectDate(context, _trialEndController),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _statusController.text.toLowerCase(),
                      decoration: InputDecoration(labelText: tr('status')),
                      items: const [
                        DropdownMenuItem(value: 'activa', child: Text('Activa')),
                        DropdownMenuItem(value: 'pausada', child: Text('Pausada')),
                        DropdownMenuItem(value: 'cancelada', child: Text('Cancelada')),
                        DropdownMenuItem(value: 'pendiente de pago', child: Text('Pendiente de pago')),
                      ],
                      onChanged: (val) => setState(() => _statusController.text = val!),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? tr('statusRequired')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cancelUrlController,
                      decoration: InputDecoration(
                        labelText: tr('cancellationUrl'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedPaymentMethodId,
                      decoration: InputDecoration(
                        labelText: tr('paymentMethodLabel'),
                      ),
                      items: (() {
                        final methods = List<Map<String, dynamic>>.from(
                          _paymentMethods,
                        );
                        methods.sort((a, b) {
                          final aDef = _isPaymentDefault(a);
                          final bDef = _isPaymentDefault(b);
                          if (aDef && !bDef) return -1;
                          if (!aDef && bDef) return 1;
                          return 0;
                        });
                        final items = methods
                            .map((method) {
                              final methodId =
                                  _parseNumericId(
                                    method['id_payment_method'],
                                  ) ??
                                  _parseNumericId(method['id']) ??
                                  _parseNumericId(method['id_metodo_pago']) ??
                                  _parseNumericId(method['idMetodoPago']);
                              if (methodId == null) {
                                return null;
                              }
                              final tipoRaw =
                                  method['tipo']?.toString() ??
                                  method['nombre']?.toString() ??
                                  '';
                              final tipo = _paymentMethodShortLabel(tipoRaw);
                              var last =
                                  method['last4']?.toString() ??
                                  method['ultimo_digitos']?.toString() ??
                                  '';
                              if (last.length > 4) {
                                last = last.substring(last.length - 4);
                              }

                              final paymentName = method['payment_name']?.toString() ?? '';
                              final String label;
                              if (paymentName.trim().isNotEmpty) {
                                label = paymentName;
                              } else {
                                label = "$tipo${last.isNotEmpty ? ' $last' : ''}";
                              }

                              return DropdownMenuItem<int>(
                                value: methodId,
                                child: Text(label),
                              );
                            })
                            .whereType<DropdownMenuItem<int>>()
                            .toList();
                        return items;
                      })(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethodId = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? tr('paymentMethodRequired') : null,
                    ),
                    const Divider(height: 32),
                    Text(
                      tr('selectCategory'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: tr('selectCategory'),
                      ),
                      items: _categories
                          .map(
                            (cat) => DropdownMenuItem<int>(
                              value: cat['id'] as int,
                              child: Text(
                                cat['nombre'] as String,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategoryId = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton.tonal(
                      onPressed: _isLoading ? null : _submitSubscription,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isEditing
                                  ? tr('editSubscription')
                                  : tr('createSubscription'),
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