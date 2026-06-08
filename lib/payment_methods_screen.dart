import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'utils.dart';
import 'create_payment_method_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key, required this.accessToken});

  final String accessToken;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

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
          }
        }

        setState(() {
          _paymentMethods = (methodsRaw ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _error = responseBody is Map && responseBody['error'] != null
            ? responseBody['error'].toString()
            : tr('loginError', {
                'statusCode': response.statusCode.toString(),
                'errorMessage': responseBody.toString(),
              });
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = tr('networkError', {'error': error.toString()});
        });
      }
    }
  }

  Future<bool> _confirmDeletePaymentMethod(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(tr('deletePaymentMethodConfirmationTitle')),
              content: Text(tr('deletePaymentMethodConfirmationMessage')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(tr('cancel')),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(tr('delete')),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _deletePaymentMethod(dynamic paymentMethodId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final uri = Uri.parse(
      'https://exrydayuvwxrapejnawg.supabase.co/functions/v1/eliminar-metodo-pago',
    );

    try {
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
        body: jsonEncode({
          'id':
              int.tryParse(paymentMethodId.toString()) ?? paymentMethodId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('paymentMethodDeletionSuccess'))));
        await _loadPaymentMethods();
        return;
      }

      if (response.statusCode == 404) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('paymentMethodNotFound'))));
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('paymentMethodDeletionFailed'))));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('networkError', {'error': error.toString()})),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToCreatePaymentMethod() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CreatePaymentMethodScreen(accessToken: widget.accessToken),
      ),
    );

    if (created == true) {
      _loadPaymentMethods();
    }
  }

  Future<void> _navigateToEditPaymentMethod(
    Map<String, dynamic> paymentMethod,
  ) async {
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePaymentMethodScreen(
          accessToken: widget.accessToken,
          paymentMethod: paymentMethod,
        ),
      ),
    );

    if (edited == true) {
      _loadPaymentMethods();
    }
  }

  String _paymentMethodTypeLabel(String? type) {
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
        return tr('other');
      default:
        return type ?? tr('unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('paymentMethodsDrawer'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            : _paymentMethods.isEmpty
            ? Center(child: Text(tr('noPaymentMethods')))
            : ListView.separated(
                itemCount: _paymentMethods.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final method = _paymentMethods[index];
                  final typeLabel = _paymentMethodTypeLabel(
                    method['tipo']?.toString(),
                  );
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _navigateToEditPaymentMethod(method),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  method['tipo']
                                              ?.toString()
                                              .toLowerCase()
                                              .contains('tarjeta') ??
                                          false
                                      ? Icons.credit_card
                                      : Icons.account_balance,
                                  size: 32,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        method['payment_name'] != null &&
                                                method['payment_name']
                                                    .toString()
                                                    .trim()
                                                    .isNotEmpty
                                            ? method['payment_name']
                                                .toString()
                                            : typeLabel,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      if (method['payment_name'] != null &&
                                          method['payment_name']
                                              .toString()
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          typeLabel,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        method['referencia_token']
                                                ?.toString() ??
                                            tr('unknown'),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                if (method['last4'] != null ||
                                    method['ultimo_digitos'] != null)
                                  buildPaymentMethodChip(
                                    context,
                                    Icons.numbers,
                                    '${tr('lastDigits')}: ${method['last4'] ?? method['ultimo_digitos']}',
                                  ),
                                if (method['mes_expiracion'] != null &&
                                    method['anio_expiracion'] != null)
                                  buildPaymentMethodChip(
                                    context,
                                    Icons.calendar_month,
                                    '${tr('expirationDate')}: ${method['mes_expiracion']}/${method['anio_expiracion']}',
                                  ),
                                if (method['predeterminado'] == true ||
                                    method['predeterminado']
                                            ?.toString()
                                            .toLowerCase() ==
                                        'true')
                                  buildPaymentMethodChip(
                                    context,
                                    Icons.star,
                                    tr('defaultPaymentMethod'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                visualDensity:
                                    VisualDensity.compact,
                                color: Theme.of(
                                  context,
                                ).colorScheme.error,
                                tooltip: tr('deletePaymentMethod'),
                                onPressed: () async {
                                  final paymentMethodId =
                                      method['id_metodo_pago'] ??
                                      method['id'];
                                  if (paymentMethodId == null) {
                                    return;
                                  }
                                  final confirmed =
                                      await _confirmDeletePaymentMethod(
                                        context,
                                      );
                                  if (!confirmed) return;
                                  await _deletePaymentMethod(
                                    paymentMethodId,
                                  );
                                },
                                icon: const Icon(Icons.delete),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreatePaymentMethod,
        icon: const Icon(Icons.add),
        label: Text(tr('addPaymentMethod')),
      ),
    );
  }
}