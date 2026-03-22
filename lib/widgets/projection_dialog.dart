import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../providers/accounting_provider.dart';
import '../models/account_model.dart';

class ProjectionDialog extends StatefulWidget {
  final AccountingProvider provider;

  const ProjectionDialog({super.key, required this.provider});

  static void show(BuildContext context, AccountingProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProjectionDialog(provider: provider),
    );
  }

  @override
  State<ProjectionDialog> createState() => _ProjectionDialogState();
}

class _ProjectionDialogState extends State<ProjectionDialog> {
  int? _selectedMonthIndex;
  late List<Map<int, double>> _history;
  late List<FlSpot> _spots;
  late double _initialNW;
  late double _totalMarketGains;

  @override
  void initState() {
    super.initState();
    _calculateProjection();
  }

  void _calculateProjection() {
    _history = [];
    _spots = [];
    _totalMarketGains = 0;

    // Estado inicial: Saldos reales actuales
    Map<int, double> currentBalances = {
      for (var acc in widget.provider.accounts) acc.id!: widget.provider.getAccountBalance(acc)
    };
    
    _initialNW = currentBalances.values.fold(0, (sum, val) => sum + val);
    _history.add(Map.from(currentBalances));
    _spots.add(FlSpot(0, _initialNW));

    // Multiplicador mensual para rentabilidad del 7% anual compuesto
    final double monthlyROI = math.pow(1.07, 1 / 12).toDouble();

    for (int month = 1; month <= 60; month++) {
      // 1. Aplicar rentabilidad de mercado (solo a Indexa)
      for (var acc in widget.provider.accounts) {
        if (acc.name.toLowerCase().contains('indexa')) {
          double before = currentBalances[acc.id!]!;
          double after = before * monthlyROI;
          _totalMarketGains += (after - before);
          currentBalances[acc.id!] = after;
        }
      }

      // 2. Aplicar movimientos programados ajustados por frecuencia
      for (var st in widget.provider.scheduledTransactions.where((st) => st.active)) {
        double monthlyAmount = 0;
        
        // CORRECCIÓN: Ajustar el monto según la frecuencia para que el impacto mensual sea real
        switch (st.frequency.toUpperCase()) {
          case 'DAILY':
            monthlyAmount = st.amount * 30.42; // Promedio días mes
            break;
          case 'WEEKLY':
            monthlyAmount = st.amount * 4.34; // Promedio semanas mes
            break;
          case 'YEARLY':
            monthlyAmount = st.amount / 12;
            break;
          case 'MONTHLY':
          default:
            monthlyAmount = st.amount;
            break;
        }

        if (st.type == 'INCOME') {
          currentBalances[st.accountId] = (currentBalances[st.accountId] ?? 0) + monthlyAmount;
        } else if (st.type == 'EXPENSE') {
          currentBalances[st.accountId] = (currentBalances[st.accountId] ?? 0) - monthlyAmount;
        } else if (st.type == 'TRANSFER' || st.type == 'TRANSFER_OUT') {
          // El dinero SIEMPRE sale de la cuenta origen
          currentBalances[st.accountId] = (currentBalances[st.accountId] ?? 0) - monthlyAmount;
          
          // Entra en el destino (Amortiza deudas o aumenta activos)
          if (st.transferAccountId != null) {
            currentBalances[st.transferAccountId!] = (currentBalances[st.transferAccountId!] ?? 0) + monthlyAmount;
          }
        }
      }

      _history.add(Map.from(currentBalances));
      double monthNW = currentBalances.values.fold(0, (sum, val) => sum + val);
      _spots.add(FlSpot(month.toDouble(), monthNW));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // CABECERA
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Simulación Financiera 5 Años', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('Cálculo basado en flujos de caja fijos', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // GRÁFICO
                  SizedBox(
                    height: 320,
                    child: LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          touchCallback: (event, response) {
                            if (response != null && response.lineBarSpots != null && event is FlTapUpEvent) {
                              setState(() {
                                _selectedMonthIndex = response.lineBarSpots!.first.spotIndex;
                              });
                            }
                          },
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => Colors.blueGrey.withValues(alpha: 0.9),
                            maxContentWidth: 220,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final monthIdx = spot.spotIndex;
                                final date = DateTime(now.year, now.month + monthIdx, 1);
                                return LineTooltipItem(
                                  '${DateFormat('MMM yyyy').format(date)}\n',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text: 'Patrimonio: ${NumberFormat.currency(symbol: '€').format(spot.y)}',
                                      style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.normal),
                                    ),
                                  ],
                                );
                              }).toList();
                            },
                          ),
                        ),
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 12,
                              getTitlesWidget: (value, meta) {
                                if (value % 12 != 0) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text('${now.year + (value / 12).toInt()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _spots,
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                if (index == _selectedMonthIndex) {
                                  return FlDotCirclePainter(radius: 6, color: Colors.orange, strokeWidth: 2, strokeColor: Colors.white);
                                }
                                return FlDotCirclePainter(radius: 0);
                              },
                            ),
                            belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // RESUMEN PRINCIPAL O MES SELECCIONADO
                  if (_selectedMonthIndex == null) 
                    _buildSummaryCard(context, 'Patrimonio Final (5 años)', _spots.last.y, isFinal: true)
                  else 
                    _buildSummaryCard(context, 'Patrimonio en ${DateFormat('MMMM yyyy').format(DateTime(now.year, now.month + _selectedMonthIndex!, 1))}', _spots[_selectedMonthIndex!].y),

                  const SizedBox(height: 24),

                  // DESGLOSE DE CUENTAS
                  if (_selectedMonthIndex != null) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Desglose de Cuentas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    _buildAccountBreakdown(_history[_selectedMonthIndex!]),
                  ] else ...[
                    // Info adicional si no hay nada seleccionado
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange),
                          SizedBox(width: 12),
                          Expanded(child: Text('Pulsa en cualquier punto del gráfico para ver el saldo de cada cuenta en ese mes.', style: TextStyle(fontSize: 12, color: Colors.orange))),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, double amount, {bool isFinal = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4), Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1)]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isFinal ? Theme.of(context).colorScheme.primary : Colors.orange, shape: BoxShape.circle), child: Icon(isFinal ? Icons.auto_graph : Icons.ads_click, color: Colors.white, size: 28)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(NumberFormat.currency(symbol: '€').format(amount), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              ])),
            ],
          ),
          if (isFinal) ...[
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('Ahorro Real', amount - _initialNW - _totalMarketGains, Colors.blue),
                _buildMiniStat('Plusvalía 7%', _totalMarketGains, Colors.green),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountBreakdown(Map<int, double> balances) {
    final accounts = widget.provider.accounts;
    final activos = accounts.where((acc) => acc.type != 'LIABILITY').toList();
    final pasivos = accounts.where((acc) => acc.type == 'LIABILITY').toList();

    return Column(
      children: [
        ...activos.map((acc) => _buildAccountItem(acc, balances[acc.id] ?? 0)),
        if (pasivos.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft, child: Text('Deudas (No amortizadas)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey))),
          const SizedBox(height: 8),
          ...pasivos.map((acc) => _buildAccountItem(acc, balances[acc.id] ?? 0)),
        ],
      ],
    );
  }

  Widget _buildAccountItem(AccountModel acc, double balance) {
    if (balance.abs() < 0.01 && acc.type != 'LIABILITY') return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(acc.icon, color: acc.color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
          Text(NumberFormat.currency(symbol: '€').format(balance), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: balance < 0 ? Colors.redAccent : null)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(NumberFormat.compactCurrency(symbol: '€').format(amount), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
      ],
    );
  }
}
