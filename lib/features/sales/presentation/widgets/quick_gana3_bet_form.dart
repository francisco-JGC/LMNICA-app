import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/currency.dart';
import '../state/cart_controller.dart';

class QuickGana3BetForm extends StatefulWidget {
  const QuickGana3BetForm({
    required this.onSubmit,
    this.onClientChanged,
    this.clientController,
    super.key,
  });

  final AddBetOutcome Function({
    required int number,
    required int amount,
    required bool isExact,
    String? client,
  }) onSubmit;

  /// Se dispara en cada keystroke del campo "Cliente". Ver
  /// `QuickBetForm.onClientChanged` para el rationale.
  final void Function(String value)? onClientChanged;

  final TextEditingController? clientController;

  @override
  State<QuickGana3BetForm> createState() => _QuickGana3BetFormState();
}

class _QuickGana3BetFormState extends State<QuickGana3BetForm> {
  final _numberCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  late final TextEditingController _clientCtrl =
      widget.clientController ?? TextEditingController();

  final _numberFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _clientFocus = FocusNode();

  bool _isEasy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _numberCtrl.addListener(_onNumberChanged);
    _amountCtrl.addListener(_onAmountChanged);
    _clientCtrl.addListener(_onClientChanged);
    _amountFocus.addListener(_onAmountFocusChanged);
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _amountCtrl.dispose();
    _clientCtrl.removeListener(_onClientChanged);
    if (widget.clientController == null) _clientCtrl.dispose();
    _numberFocus.dispose();
    _amountFocus.removeListener(_onAmountFocusChanged);
    _amountFocus.dispose();
    _clientFocus.dispose();
    super.dispose();
  }

  void _onClientChanged() {
    widget.onClientChanged?.call(_clientCtrl.text);
  }

  /// Ver `QuickBetForm._onAmountFocusChanged`.
  void _onAmountFocusChanged() {
    if (_amountFocus.hasFocus && _amountCtrl.text.isNotEmpty) {
      _amountCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _amountCtrl.text.length,
      );
    }
  }

  void _onNumberChanged() {
    if (_numberCtrl.text.length == 3) {
      _amountFocus.requestFocus();
    }
  }

  void _onAmountChanged() {
    if (_amountCtrl.text.length == 3) {
      _clientFocus.requestFocus();
    }
  }

  void _submit() {
    final number = int.tryParse(_numberCtrl.text);
    final amount = int.tryParse(_amountCtrl.text);

    if (number == null || number < 0 || number > 999) {
      setState(() => _errorMessage = 'Número inválido (000 - 999)');
      _numberFocus.requestFocus();
      return;
    }
    if (amount == null || amount < 1 || amount > 999) {
      setState(() => _errorMessage = 'Monto inválido (1 - 999)');
      _amountFocus.requestFocus();
      return;
    }

    final outcome = widget.onSubmit(
      number: number,
      amount: amount,
      isExact: !_isEasy,
      client: _clientCtrl.text,
    );

    if (outcome == AddBetOutcome.invalid) {
      setState(() => _errorMessage = 'Datos inválidos');
      return;
    }

    _numberCtrl.clear();
    // El monto NO se limpia — ver `QuickBetForm._submit`.
    setState(() => _errorMessage = null);
    _numberFocus.requestFocus();
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
                  controller: _numberCtrl,
                  focusNode: _numberFocus,
                  autofocus: true,
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
                    labelText: 'Número',
                    hintText: '000',
                    counterText: '',
                    isDense: true,
                  ),
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
          Row(
            children: [
              Checkbox(
                value: _isEasy,
                onChanged: (v) => setState(() => _isEasy = v ?? false),
              ),
              GestureDetector(
                onTap: () => setState(() => _isEasy = !_isEasy),
                child: const Text(
                  'Fácil',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
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
