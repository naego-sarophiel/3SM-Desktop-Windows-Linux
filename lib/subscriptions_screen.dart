import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'utils.dart';
import 'login_screen.dart';
import 'create_subscription_screen.dart';
import 'payment_methods_screen.dart';
import 'settings_screen.dart';

enum SubscriptionSort {
  nearPayment,
  highestPrice,
  lowestPrice,
  alphabetical,
}

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({
    super.key,
    required this.accessToken,
    required this.displayName,
  });

  final String accessToken;
  final String displayName;

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _usuario;
  List<dynamic> _suscripciones = [];
  SubscriptionSort _currentSort = SubscriptionSort.nearPayment;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final uri = Uri.parse(
      'https://exrydayuvwxrapejnawg.supabase.co/functions/v1/mis-suscripciones',
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
      if (response.statusCode == 200 &&
          responseBody is Map &&
          responseBody['ok'] == true) {
        setState(() {
          _usuario = (responseBody['usuario'] as Map<dynamic, dynamic>?)
              ?.cast<String, dynamic>();
          _suscripciones =
              (responseBody['suscripciones'] as List<dynamic>?) ?? [];
          _isLoading = false;
          _applySort();
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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = tr('networkError', {'error': error.toString()});
      });
    }
  }

  Future<bool> _confirmDeleteSubscription(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(tr('deleteConfirmationTitle')),
              content: Text(tr('deleteConfirmationMessage')),
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

  Future<void> _deleteSubscription(dynamic subscriptionId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final uri = Uri.parse(
      'https://exrydayuvwxrapejnawg.supabase.co/functions/v1/borrar-suscripcion',
    );

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
        body: jsonEncode({
          'id_suscripcion':
              int.tryParse(subscriptionId.toString()) ?? subscriptionId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('deletionSuccess'))));
        await _loadSubscriptions();
        return;
      }

      if (response.statusCode == 404) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('subscriptionNotFound'))));
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('deletionFailed'))));
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

  void _applySort() {
    _suscripciones.sort((a, b) {
      final subA = a as Map<dynamic, dynamic>;
      final subB = b as Map<dynamic, dynamic>;

      switch (_currentSort) {
        case SubscriptionSort.nearPayment:
          final dateA = subA['proxima_fecha_cobro']?.toString() ?? '9999-12-31';
          final dateB = subB['proxima_fecha_cobro']?.toString() ?? '9999-12-31';
          return dateA.compareTo(dateB);
        case SubscriptionSort.highestPrice:
          final priceA =
              double.tryParse(subA['costo_mensual']?.toString() ?? '0') ?? 0.0;
          final priceB =
              double.tryParse(subB['costo_mensual']?.toString() ?? '0') ?? 0.0;
          return priceB.compareTo(priceA);
        case SubscriptionSort.lowestPrice:
          final priceA =
              double.tryParse(subA['costo_mensual']?.toString() ?? '0') ?? 0.0;
          final priceB =
              double.tryParse(subB['costo_mensual']?.toString() ?? '0') ?? 0.0;
          return priceA.compareTo(priceB);
        case SubscriptionSort.alphabetical:
          final nameA =
              subA['nombre_servicio']?.toString().toLowerCase() ?? '';
          final nameB =
              subB['nombre_servicio']?.toString().toLowerCase() ?? '';
          return nameA.compareTo(nameB);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${tr('subscriptionsOf')} ${widget.displayName}'),
        actions: [
          PopupMenuButton<SubscriptionSort>(
            icon: const Icon(Icons.sort),
            tooltip: tr('sortSubscriptions'),
            onSelected: (SubscriptionSort result) {
              setState(() {
                _currentSort = result;
                _applySort();
              });
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<SubscriptionSort>>[
              PopupMenuItem<SubscriptionSort>(
                value: SubscriptionSort.nearPayment,
                child: Text(tr('sortNearPayment')),
              ),
              PopupMenuItem<SubscriptionSort>(
                value: SubscriptionSort.highestPrice,
                child: Text(tr('sortHighestPrice')),
              ),
              PopupMenuItem<SubscriptionSort>(
                value: SubscriptionSort.lowestPrice,
                child: Text(tr('sortLowestPrice')),
              ),
              PopupMenuItem<SubscriptionSort>(
                value: SubscriptionSort.alphabetical,
                child: Text(tr('sortAlphabetical')),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('appTitle'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: Text(tr('subscriptionsDrawer')),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: Text(tr('paymentMethodsDrawer')),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PaymentMethodsScreen(accessToken: widget.accessToken),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(tr('settingsDrawer')),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(tr('aboutUsDrawer')),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: tr('appTitle'),
                  applicationVersion: '1.0.0',
                  applicationIcon: Icon(
                    Icons.account_balance_wallet,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(tr('aboutUsMessage')),
                    ),
                  ],
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(tr('logoutDrawer')),
              onTap: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                await clearSavedToken();
                if (!mounted) return;
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_usuario != null) ...[
                    Text(
                      '${tr('userLabel')}: ${_usuario!['nombre'] ?? widget.displayName}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${tr('emailLabelShort')}: ${_usuario!['correo'] ?? ''}',
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_suscripciones.isNotEmpty) ...[
                    Builder(builder: (context) {
                      final activeSubscriptions = _suscripciones.where((s) {
                        final status = (s['estado'] ?? '').toString().toLowerCase();
                        return status.contains('activa') || status.contains('active');
                      }).toList();

                      Map<String, double> totals = {};
                      for (var s in activeSubscriptions) {
                        final currency = s['moneda']?.toString() ?? 'EUR';
                        final cost = double.tryParse(s['costo_mensual']?.toString() ?? '0') ?? 0;
                        final cycle = (s['ciclo_facturacion'] ?? '').toString().toLowerCase();

                        double monthlyContribution;
                        if (cycle == 'semanal') {
                          monthlyContribution = (cost * 52) / 12;
                        } else if (cycle == 'anual') {
                          monthlyContribution = cost / 12;
                        } else {
                          monthlyContribution = cost;
                        }

                        totals[currency] = (totals[currency] ?? 0) + monthlyContribution;
                      }

                      if (totals.isEmpty) return const SizedBox.shrink();

                      return Card(
                        elevation: 2,
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('monthlyTotalSpend'), style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 4),
                              ...totals.entries.map((e) => Text(
                                '${e.key} ${e.value.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              )),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: _suscripciones.isEmpty
                        ? Center(child: Text(tr('noSubscriptions')))
                        : ListView.separated(
                            itemCount: _suscripciones.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final suscripcion =
                                  _suscripciones[index] as Map<String, dynamic>;
                              final categoria =
                                  (suscripcion['categorias']
                                          as Map<dynamic, dynamic>?)
                                      ?.cast<String, dynamic>();
                              return InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () =>
                                    _navigateToEditSubscription(suscripcion),
                                child: Card(
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                suscripcion['nombre_servicio']
                                                        ?.toString() ??
                                                    tr('serviceName'),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            _buildStatusBadge(
                                              suscripcion['estado']
                                                      ?.toString() ??
                                                  '',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${suscripcion['moneda'] ?? ''} ${suscripcion['costo_mensual'] ?? ''}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '/ ${suscripcion['ciclo_facturacion'] ?? ''}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _buildInfoChip(
                                              Icons.calendar_month,
                                              '${tr('nextLabel')} ${suscripcion['proxima_fecha_cobro'] ?? '-'}',
                                            ),
                                            _buildInfoChip(
                                              Icons.event,
                                              '${tr('chargeLabel')} ${suscripcion['fecha_cobro'] ?? '-'}',
                                            ),
                                            if (suscripcion['fecha_fin_prueba'] !=
                                                null)
                                              _buildInfoChip(
                                                Icons.verified,
                                                '${tr('trialEndLabel')} ${suscripcion['fecha_fin_prueba']}',
                                              ),
                                            if (suscripcion['url_cancelacion'] !=
                                                    null &&
                                                suscripcion['url_cancelacion']
                                                    .toString()
                                                    .isNotEmpty)
                                              _buildInfoChip(
                                                Icons.link,
                                                tr('cancelLabel'),
                                                subtitle:
                                                    suscripcion['url_cancelacion']
                                                        ?.toString(),
                                              ),
                                          ],
                                        ),
                                        if (categoria != null) ...[
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _parseColor(
                                                categoria['color']
                                                        ?.toString() ??
                                                    '#000000',
                                              ).withAlpha((0.15 * 255).round()),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _getIconData(
                                                    categoria['icon']
                                                            ?.toString() ??
                                                        '',
                                                  ),
                                                  color: _parseColor(
                                                    categoria['color']
                                                            ?.toString() ??
                                                        '#000000',
                                                  ),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  categoria['nombre']
                                                          ?.toString() ??
                                                      '',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            tooltip: tr('deleteSubscription'),
                                            onPressed: () async {
                                              final subscriptionId =
                                                  suscripcion['id_suscripcion'] ??
                                                  suscripcion['id'];
                                              if (subscriptionId == null) {
                                                return;
                                              }
                                              final confirmed =
                                                  await _confirmDeleteSubscription(
                                                    context,
                                                  );
                                              if (!confirmed) return;
                                              await _deleteSubscription(
                                                subscriptionId,
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
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateSubscription,
        icon: const Icon(Icons.add),
        label: Text(tr('newSubscription')),
      ),
    );
  }

  Future<void> _navigateToCreateSubscription() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CreateSubscriptionScreen(accessToken: widget.accessToken),
      ),
    );

    if (created == true) {
      _loadSubscriptions();
    }
  }

  Future<void> _navigateToEditSubscription(
    Map<String, dynamic> subscription,
  ) async {
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateSubscriptionScreen(
          accessToken: widget.accessToken,
          subscription: subscription,
        ),
      ),
    );

    if (edited == true) {
      _loadSubscriptions();
    }
  }

  Color _parseColor(String colorString) {
    try {
      final hex = colorString.replaceAll('#', '');
      final value = int.parse(hex, radix: 16);
      return Color((hex.length == 6 ? 0xFF000000 : 0) | value);
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'play-circle':
        return Icons.play_circle_filled;
      case 'music':
        return Icons.music_note;
      case 'briefcase':
        return Icons.work;
      case 'gamepad':
        return Icons.sports_esports;
      case 'newspaper':
        return Icons.newspaper;
      case 'code':
        return Icons.code;
      case 'heart':
        return Icons.favorite;
      case 'book':
        return Icons.book;
      case 'etiqueta':
        return Icons.label;
      default:
        return Icons.category;
    }
  }

  Widget _buildStatusBadge(String status) {
    final lower = status.toLowerCase();
    final isActive = lower.contains('activa') || lower.contains('active');
    final color = isActive ? Colors.green.shade600 : Colors.orange.shade700;
    final label = status.isEmpty
        ? 'Desconocido'
        : '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outline.withAlpha((0.4 * 255).round()),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}