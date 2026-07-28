import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/currency.dart';
import '../../domain/entities/date_bet.dart';
import '../state/cart_controller.dart';

class QuickDateBetForm extends StatefulWidget {
  const QuickDateBetForm({
    required this.onSubmit,
    this.clientController,
    super.key,
  });

  final AddBetOutcome Function({
    required int day,
    required int month,
    required int amount,
    String? client,
  }) onSubmit;

  final TextEditingController? clientController;

  @override
  State<QuickDateBetForm> createState() => _QuickDateBetFormState();
}

class _QuickDateBetFormState extends State<QuickDateBetForm> {
  final _dayCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  late final TextEditingController _clientCtrl =
      widget.clientController ?? TextEditingController();

  final _dayFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _clientFocus = FocusNode();

  late int _month = DateTime.now().month;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dayCtrl.addListener(_onDayChanged);
    _amountCtrl.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _amountCtrl.dispose();
    if (widget.clientController == null) _clientCtrl.dispose();
    _dayFocus.dispose();
    _amountFocus.dispose();
    _clientFocus.dispose();
    super.dispose();
  }

  void _onDayChanged() {
    if (_dayCtrl.text.length == 2) {
      _amountFocus.requestFocus();
    }
  }

  void _onAmountChanged() {
    if (_amountCtrl.text.length == 3) {
      _clientFocus.requestFocus();
    }
  }

  void _submit() {
    final day = int.tryParse(_dayCtrl.text);
    final amount = int.tryParse(_amountCtrl.text);

    if (day == null || day < 1 || day > 31) {
      setState(() => _errorMessage = 'Día inválido (01 - 31)');
      _dayFocus.requestFocus();
      return;
    }
    if (amount == null || amount < 1 || amount > 999) {
      setState(() => _errorMessage = 'Monto inválido (1 - 999)');
      _amountFocus.requestFocus();
      return;
    }

    final outcome = widget.onSubmit(
      day: day,
      month: _month,
      amount: amount,
      client: _clientCtrl.text,
    );

    if (outcome == AddBetOutcome.invalid) {
      setState(() => _errorMessage = 'Datos inválidos');
      return;
    }

    _dayCtrl.clear();
    _amountCtrl.clear();
    setState(() => _errorMessage = null);
    _dayFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dayCtrl,
                  focusNode: _dayFocus,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Día',
                    hintText: '00',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _month,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Mes',
                    isDense: true,
                  ),
                  items: [
                    for (var i = 1; i <= 12; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          kMonthAbbreviations[i - 1],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _month = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  focusNode: _amountFocus,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monto',
                    hintText: '000',
                    prefixText: '$kCurrencySymbol ',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _clientCtrl,
                  focusNode: _clientFocus,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Cliente (opcional)',
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add),
                tooltip: 'Agregar',
                onPressed: _submit,
              ),
            ],
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
