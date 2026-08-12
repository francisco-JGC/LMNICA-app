import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/currency.dart';
import '../state/cart_controller.dart';

class QuickBetForm extends StatefulWidget {
  const QuickBetForm({
    required this.onSubmit,
    this.onClientChanged,
    this.clientController,
    super.key,
  });

  final AddBetOutcome Function({
    required int number,
    required int amount,
    String? client,
  }) onSubmit;

  /// Se dispara en cada keystroke del campo "Cliente". El parent lo usa
  /// para mantener el `cart.client` alineado con lo que ve el vendedor
  /// aunque no submitee un número. Sin esto, escribir el nombre después
  /// del último bet y darle "Imprimir" mandaba el ticket sin cliente.
  final void Function(String value)? onClientChanged;

  final TextEditingController? clientController;

  @override
  State<QuickBetForm> createState() => _QuickBetFormState();
}

class _QuickBetFormState extends State<QuickBetForm> {
  final _numberCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  late final TextEditingController _clientCtrl =
      widget.clientController ?? TextEditingController();

  final _numberFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _clientFocus = FocusNode();

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _numberCtrl.addListener(_onNumberChanged);
    _amountCtrl.addListener(_onAmountChanged);
    _clientCtrl.addListener(_onClientChanged);
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _amountCtrl.dispose();
    _clientCtrl.removeListener(_onClientChanged);
    if (widget.clientController == null) _clientCtrl.dispose();
    _numberFocus.dispose();
    _amountFocus.dispose();
    _clientFocus.dispose();
    super.dispose();
  }

  void _onClientChanged() {
    widget.onClientChanged?.call(_clientCtrl.text);
  }

  void _onNumberChanged() {
    if (_numberCtrl.text.length == 2) {
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

    if (number == null || number < 0 || number > 99) {
      setState(() => _errorMessage = 'Número inválido (00 - 99)');
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
      client: _clientCtrl.text,
    );

    if (outcome == AddBetOutcome.invalid) {
      setState(() => _errorMessage = 'Datos inválidos');
      return;
    }

    _numberCtrl.clear();
    _amountCtrl.clear();
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
                    LengthLimitingTextInputFormatter(2),
                  ],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Número',
                    hintText: '00',
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
